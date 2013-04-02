/*
 * $Id:$
 */

#include "oordb.ch"

CLASS TMachine FROM TTable
  DEFINE FIELDS
  DEFINE PRIMARY INDEX
  
  PROPERTY TableFileName VALUE "data/Machine"
  
END CLASS

BEGIN FIELDS CLASS TMachine
  ADD INTEGER FIELD "MachineId"
  ADD STRING FIELD "Name" SIZE 20
END FIELDS CLASS

BEGIN PRIMARY INDEX CLASS TMachine
  DEFINE INDEX "Primary" KEYFIELD "MachineId" AUTOINCREMENT
END PRIMARY INDEX CLASS
