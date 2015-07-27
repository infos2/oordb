/*
 *
 */

#include "oordb.ch"
#include "xerror.ch"

/*
    TFieldTable
*/
CLASS TFieldTable FROM TField

   PRIVATE:

   DATA FObjClass
   DATA FLinkedTable          /* holds the Table object */
   DATA FLinkedTableMasterSource
   METHOD BuildLinkedTable()
   METHOD SetLinkedTableMasterSource( linkedTable )
   METHOD SetObjClass( objClass ) INLINE ::FObjClass := objClass

   PROTECTED:

   DATA buildingLinkedTable
   DATA FCalcMethod
   DATA FcalculatingLinkedTable INIT .F.
   DATA FClassInit
   DATA FFieldType INIT ftTable
   DATA FonDataChangeBlock
   DATA FonDataObj
   DATA FType INIT "TableField"
   DATA FtypeNameList INIT hb_hSetCaseMatch( {"es"=>"Documento"} )
   DATA FValidValuesLabelField
   DATA FValType INIT "O"
   METHOD GetDBS_LEN INLINE ::BaseKeyField():DBS_LEN
   METHOD GetDBS_TYPE INLINE iif( ::BaseKeyField():DBS_TYPE = "+", "I", ::BaseKeyField():DBS_TYPE )
   METHOD GetLabel()
   METHOD GetLinkedTable
   METHOD GetEmptyValue() INLINE ::BaseKeyField():EmptyValue
   METHOD GetFieldReadBlock()
   METHOD GetOnDataChange()
   METHOD GetValidValues()
   METHOD SetOnDataChange( onDataChangeBlock )

   PUBLIC:

   METHOD BaseKeyField() // Returns the non-TFieldTable associated to this obj
   METHOD DataObj
   METHOD GetAsDisplay() INLINE ::GetKeyVal()
   METHOD GetKeyVal( keyVal )
   METHOD GetAsString()       // INLINE ::LinkedTable:KeyField:AsString()
   METHOD GetAsVariant( ... )
   METHOD IndexExpression( fieldName )
   METHOD SetClassInit( clsInit ) INLINE ::FClassInit := clsInit
   METHOD SetValidValues( validValues, ignoreUndetermined, labelField )
   PROPERTY KeySize READ BaseKeyField():KeySize
   PROPERTY LinkedTable READ GetLinkedTable
   PROPERTY LinkedTableAssigned READ FLinkedTableMasterSource != NIL
   PROPERTY LinkedTableMasterSource READ FLinkedTableMasterSource WRITE SetLinkedTableMasterSource
   PROPERTY MasterKeyVal
   PROPERTY ObjClass READ FObjClass WRITE SetObjClass
   PROPERTY OnDataChange READ GetOnDataChange WRITE SetOnDataChange
   PROPERTY Size READ BaseKeyField():Size
   PROPERTY ValidValuesLabelField READ FValidValuesLabelField

ENDCLASS

/*
    BaseKeyField
*/
METHOD FUNCTION BaseKeyField() CLASS TFieldTable

   LOCAL baseKeyField

   IF ::FLinkedTable != NIL .OR. !Empty( ::GetLinkedTable() )
      baseKeyField := ::FLinkedTable:BaseKeyField
      IF baseKeyField = NIL
         ::No_BaseKeyField_Defined()
      ENDIF
   ENDIF

   RETURN baseKeyField

/*
    BuildLinkedTable
*/
METHOD PROCEDURE BuildLinkedTable() CLASS TFieldTable

   LOCAL masterSource
   LOCAL className
   LOCAL fld
   LOCAL classInit

   IF ::FLinkedTable = NIL .AND. ::buildingLinkedTable = NIL

      ::buildingLinkedTable := .T.

      IF Empty( ::FObjClass )
         RAISE TFIELD ::Name ERROR "TFieldTable has not a ObjClass value."
      ENDIF

        /*
         * Solve using the default ObjClass
         */
      IF ::FTable:MasterSource != NIL .AND. ::FTable:MasterSource:IsDerivedFrom( ::FObjClass ) .AND. ::IsMasterFieldComponent
         ::FLinkedTable := ::FTable:MasterSource
      ELSE
         IF ::FLinkedTableMasterSource != NIL
            IF ValType( ::FLinkedTableMasterSource ) = "B"
                masterSource := ::FLinkedTableMasterSource:Eval( ::FTable )
            ELSE
                masterSource := ::FLinkedTableMasterSource
            ENDIF
         ELSEIF ::FTable:IsDerivedFrom( ::Table:GetMasterSourceClassName() ) // ( ::FObjClass ) )
            masterSource := ::FTable
         ENDIF

         ::FLinkedTable := __ClsInstFromName( ::FObjClass )

         IF ::FLinkedTable:IsDerivedFrom( ::FTable:ClassName() )
//            RAISE TFIELD ::Name ERROR "Denied: To create TFieldTable's linked table derived from the same field's table class."
         ENDIF

         IF !::FLinkedTable:IsDerivedFrom( "TTable" )
            RAISE TFIELD ::Name ERROR "Denied: To create TFieldTable's linked table NOT derived from a TTable class."
         ENDIF

         /* check if we still need a mastersource and it exists in TFieldTable's Table */
         IF Empty( masterSource )
            className := ::FLinkedTable:GetMasterSourceClassName()
            IF ::FTable:IsDerivedFrom( className )
               masterSource := ::FTable
            ELSEIF !Empty( className ) .AND. ! Empty( fld := ::FTable:FieldByObjClass( className, .T. ) )
               masterSource := fld
            ENDIF
         ENDIF
         ::FLinkedTable:New( masterSource )
         classInit := ::FClassInit
      ENDIF

      IF !HB_ISOBJECT( ::FLinkedTable ) .OR. ! ::FLinkedTable:IsDerivedFrom( "TTable" )
         RAISE TFIELD ::Name ERROR "Default value is not a TTable object."
      ENDIF

        /*
         * Attach the current DataObj to the one in table to sync when table changes
         * MasterFieldComponents are ignored, a child cannot change his parent :)
         */
      /* 
        TODO: Remove !::IsMasterFieldComponent
        TODO: Add Warn/Err when trying to set value to a master field component ( SetAsVariant ? )
        TODO: Revise REUSEFIELD clause
      */
      
      IF !::IsMasterFieldComponent .AND. ::FLinkedTable:LinkedObjField == NIL
            /*
             * LinkedObjField is linked to the FIRST TFieldTable were it is referenced
             * this has to be the most top level MasterSource table
             */
         ::FLinkedTable:LinkedObjField := Self
      ELSE
            /*
             * We need to set this field as READONLY, because their LinkedTable
             * belongs to a some TFieldTable in some MasterSource table
             * so this TFieldTable cannot modify the physical database here
             */
         // ::ReadOnly := .T.
      ENDIF

      IF classInit != NIL
         classInit:Eval( ::FLinkedTable )
      ENDIF

      ::buildingLinkedTable := NIL

   ENDIF

   RETURN

/*
    DataObj
    Syncs the Table with the key in buffer
*/
METHOD FUNCTION DataObj CLASS TFieldTable

   LOCAL linkedTable
   LOCAL linkedObjField
   LOCAL keyVal

   linkedTable := ::GetLinkedTable()

   IF ::FonDataObj = NIL

      ::FonDataObj := .T.

      IF linkedTable != NIL

         IF linkedTable:isMetaTable
            linkedTable:isMetaTable := .F.
         ENDIF

         IF ::FonDataChangeBlock != NIL
            linkedTable:OnDataChangeBlock := ::FonDataChangeBlock
            linkedTable:OnDataChangeBlock_Param := ::Table
            ::FonDataChangeBlock := NIL
         ENDIF

         IF linkedTable:State = dsBrowse
            IF ::IsMasterFieldComponent .AND. ::FTable:FUnderReset

            ELSE
                /*
                    to sure a resync with linkedTable mastersource table
                    on TFieldTable's that have a mastersource field (another TFieldTable)
                    in the same table
                */
               IF !Empty( linkedTable:MasterSource ) .AND. !Empty( linkedTable:MasterSource:LinkedObjField ) .AND. linkedTable:MasterSource:LinkedObjField:Table == ::FTable
                  linkedTable:MasterSource:LinkedObjField:DataObj()
               ENDIF
               /* to be sure of mastersource synced with linkedTable */
               IF linkedTable:MasterSource != NIL .AND. !linkedTable:MasterSource:BaseKeyField:KeyVal == ::FMasterKeyVal
                  IF linkedTable:InsideScope()
                     // linkedTable:GetCurrentRecord()
                  ELSE
                     /* to don't attempt to write into a LinkedObjField */
                     linkedObjField := linkedTable:LinkedObjField
                     linkedTable:LinkedObjField := NIL
                     linkedTable:dbGoTop()
                     linkedTable:LinkedObjField := linkedObjField
                  ENDIF
                  ::FMasterKeyVal := linkedTable:MasterSource:BaseKeyField:KeyVal
               ENDIF
               keyVal := ::GetKeyVal()
               /* Syncs with the current value */
               IF !::FTable:MasterSource == linkedTable .AND. !linkedTable:BaseKeyField:KeyVal == keyVal
                  linkedObjField := linkedTable:LinkedObjField
                  linkedTable:LinkedObjField := NIL
                  linkedTable:BaseKeyField:SetKeyVal( keyVal )
                  linkedTable:LinkedObjField := linkedObjField
               ENDIF
            ENDIF
         ELSE
            IF linkedTable:MasterSource != NIL .AND. AScan( { dsEdit, dsInsert }, linkedTable:State ) > 0
               ::FMasterKeyVal := linkedTable:MasterSource:BaseKeyField:KeyVal
            ENDIF
         ENDIF
      ENDIF

      ::FonDataObj := NIL

   ENDIF

   RETURN linkedTable

/*
    GetAsString
*/
METHOD FUNCTION GetAsString() CLASS TFieldTable
   RETURN ::DataObj:GetAsString()

/*
    GetAsVariant
*/
METHOD FUNCTION GetAsVariant( ... ) CLASS TFieldTable

   LOCAL variant

   variant := ::Super:GetAsVariant( ... )

   IF HB_ISOBJECT( variant )

      IF variant:IsDerivedFrom( "TFieldTable" )
         // RETURN variant:DataObj:GetAsVariant()
         RETURN variant:GetAsVariant()
      ELSEIF variant:IsDerivedFrom( "TTable" )
         IF variant:BaseKeyField = NIL

            THROW ERROR OODB_ERR__NO_BASEKEYFIELD ON variant

         ENDIF
         RETURN variant:BaseKeyField:GetAsVariant()
      ENDIF

   ENDIF

   RETURN variant

/*
    GetFieldReadBlock
*/
METHOD FUNCTION GetFieldReadBlock() CLASS TFieldTable

   IF ::FFieldReadBlock = NIL .AND. ::Super:GetFieldReadBlock() = NIL
      IF ::FLinkedTable = NIL
         IF ::FcalculatingLinkedTable
            ::BuildLinkedTable() /* no result from calculating, so create table from ObjClass name */
         ELSE
            ::GetLinkedTable()
         ENDIF
      ENDIF
      ::FFieldReadBlock := {|| ::FLinkedTable }
   ENDIF

   RETURN ::FFieldReadBlock

/*
    GetKeyVal
*/
METHOD FUNCTION GetKeyVal( keyVal ) CLASS TFieldTable

   IF keyVal = NIL
      keyVal := ::GetAsVariant()
   ENDIF

   RETURN ::BaseKeyField:GetKeyVal( keyVal )

/*
    GetLabel
*/
METHOD FUNCTION GetLabel() CLASS TFieldTable

   IF !Empty( ::FLabel )
      RETURN ::FLabel
   ENDIF
   IF ::BaseKeyField != NIL
      RETURN ::BaseKeyField:Label
   ENDIF

   RETURN ""

/*
    GetLinkedTable
*/
METHOD FUNCTION GetLinkedTable CLASS TFieldTable

   LOCAL result

   IF ::FCalculated

      IF !::FcalculatingLinkedTable

         ::FcalculatingLinkedTable := .T.

         /* Alias can be NIL if table cannot be instanced yet */
         IF ::FTable:Alias == NIL
            result := ::FieldReadBlock:Eval( ::FTable )
         ELSE
            result := ::FTable:Alias:Eval( ::FieldReadBlock, ::FTable )
         ENDIF

         IF result != NIL
            IF HB_ISOBJECT( result )
               IF result:IsDerivedFrom( "TTable" )
                  ::FLinkedTable := result
               ELSEIF result:IsDerivedFrom( "TFieldTable" )
                  ::FLinkedTable := result:DataObj()
               ENDIF
            ELSE /* the basekey field value is returned for the calculated field */
               IF ::FLinkedTable = NIL
                  ::BuildLinkedTable()
               ENDIF
               ::FLinkedTable:BaseKeyField:Value := result
            ENDIF
         ENDIF

         IF !::IsMasterFieldComponent .AND. ::FLinkedTable != NIL .AND. ::FLinkedTable:LinkedObjField == NIL
            ::FLinkedTable:LinkedObjField := Self
         ENDIF

         ::FcalculatingLinkedTable := .F.

      ELSE

         ::BuildLinkedTable()

      ENDIF

   ELSE

      IF ::FLinkedTable == NIL
         ::BuildLinkedTable()
      ENDIF

   ENDIF

   RETURN ::FLinkedTable

/*
    GetOnDataChange
*/
METHOD FUNCTION GetOnDataChange() CLASS TFieldTable
   RETURN ::GetLinkedTable:OnDataChangeBlock

/*
    GetValidValues
*/
METHOD FUNCTION GetValidValues() CLASS TFieldTable

   LOCAL hValues
   LOCAL fld

   IF ::FValidValuesLabelField == .T.
      hValues := { => }
      fld := ::LinkedTable:FieldByName( ::FValidValues )
      ::LinkedTable:StatePush()
      ::LinkedTable:dbGoTop()
      WHILE !::LinkedTable:Eof()
         hValues[ ::LinkedTable:KeyVal ] := fld:Value
         ::LinkedTable:dbSkip()
      ENDDO
      ::LinkedTable:StatePull()
      RETURN hValues
   ENDIF

   RETURN ::Super:GetValidValues()

/*
    IndexExpression
*/
METHOD FUNCTION IndexExpression( fieldName ) CLASS TFieldTable
   LOCAL itm

   IF ::FIndexExpression != NIL
      RETURN ::FIndexExpression
   ENDIF

   IF ::Calculated
      RETURN NIL
   ENDIF

   IF fieldName = NIL
      IF ::FUsingField = NIL
         fieldName := ::FFieldExpression
      ELSE
         fieldName := ::FUsingField:FieldExpression
      ENDIF
   ENDIF

   IF fieldName = NIL .AND. ::FFieldMethodType = "A"
      fieldName := {}
      FOR EACH itm IN ::FFieldArrayIndex
         AAdd( fieldName, ::FTable:FieldList[ itm ]:IndexExpression )
      NEXT
   ENDIF

   RETURN ::BaseKeyField:IndexExpression( fieldName )

/*
    SetLinkedTableMasterSource
*/
METHOD PROCEDURE SetLinkedTableMasterSource( linkedTable ) CLASS TFieldTable

   SWITCH ValType( linkedTable )
   CASE "C"
      linkedTable := ::Table:FieldByName( linkedTable )
   CASE "O"
      IF linkedTable:IsDerivedFrom( "TFieldTable" ) .OR. linkedTable:IsDerivedFrom( "TTable" )
         EXIT
      ENDIF
   CASE "B"
      EXIT
   OTHERWISE
      RAISE ERROR "Invalid master source value..."
   ENDSWITCH

   ::FLinkedTableMasterSource := linkedTable

   RETURN

/*
    SetOnDataChange
*/
METHOD PROCEDURE SetOnDataChange( onDataChangeBlock ) CLASS TFieldTable

   ::FonDataChangeBlock := onDataChangeBlock

   RETURN

/*
    SetValidValues
*/
METHOD PROCEDURE SetValidValues( validValues, ignoreUndetermined, labelField ) CLASS TFieldTable

   ::Super:SetValidValues( validValues, ignoreUndetermined )
   ::FValidValuesLabelField := labelField

   RETURN

/*
    ENDCLASS TFieldTable
*/

