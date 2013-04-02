/*
 * $Id: dbf1.prg 13 2012-03-03 20:50:58Z tfonrouge $
 */

#include "oordb.ch"

CLASS TDbf1 FROM TTable
PUBLIC:
  DEFINE FIELDS
  PROPERTY TableFileName VALUE "test"
ENDCLASS

BEGIN FIELDS CLASS TDbf1

  ADD STRING  FIELD "First" SIZE 20
  ADD STRING  FIELD "Last" SIZE 20
  ADD STRING  FIELD "Street" SIZE 30
  ADD STRING  FIELD "City" SIZE 30
  ADD STRING  FIELD "State" SIZE 2
  ADD STRING  FIELD "Zip" SIZE 10
  ADD DATE    FIELD "HireDate"
  ADD LOGICAL FIELD "Married"
  ADD NUMERIC FIELD "Age" LEN 2 DEC 0
  ADD NUMERIC FIELD "Salary" LEN 6 DEC 0 PICTURE "$ 999,999.99"
  ADD STRING  FIELD "Notes" SIZE 70

END FIELDS CLASS

PROCEDURE Main()
  LOCAL t
  LOCAL fld

  t := TDbf1():New()

  t:DbGoTop()

  WHILE !t:Eof()
    FOR EACH fld IN t:FieldList
      ?? fld:AsString + "|"
    NEXT
    ?
    t:DbSkip()
  ENDDO

RETURN
