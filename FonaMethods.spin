DAT programName         byte "FonaMethods", 0
CON
{{
  By Duane Degn
  June 6, 2015
  
  This program using six of the Propeller's eight cogs.
  Five of the cogs are used to create software UARTs.
  One cog is used to monitor these UARTs for new data.
  
}}
{
  ******* Private Notes *******
  
}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MILLISECOND = CLK_FREQ / 1_000

  LONG_SIZE = 4
  WORD_SIZE = 2
  QUOTE = 34
  
  TIME_TIL_SERIAL_RELEASE = 2 * MILLISECOND ' To prevent fragmented serial data
  INIT_TIMEOUT = 500 * MILLISECOND
  NETWORK_TIMEOUT = 1_000 * MILLISECOND
  COMMAND_TIMEOUT = 500 * MILLISECOND
  RING_CHECK_TIMEOUT = 5 * MILLISECOND
  SEND_SMS_TIMEOUT = 5_000 * MILLISECOND
  
  NETWORK_NO_CONNECTION = 800
  NETWORK_READY = 3_000
  NETWORK_GPRS_DATA_ACTIVE = 300

  ' networkState enumeration
  #0, FONA_OFF_NETWORK, NO_CONNECTION_NETWORK, READY_NETWORK, GPRS_DATA_ACTIVE_NETWORK

  MAX_NUMBER_OF_RECORDS = 64

  HEADER_EEPROM_LOC = $8000
  SIZE_OF_HEADER_EEPROM = $10
  
  INDEX_EEPROM_LOC = HEADER_EEPROM_LOC + SIZE_OF_HEADER_EEPROM
  INDEX_ELEMENT_SIZE = WORD_SIZE
  SIZE_OF_INDEX_EEPROM = INDEX_ELEMENT_SIZE * MAX_NUMBER_OF_RECORDS
  
  FIRST_RECORD_EEPROM_LOC = INDEX_EEPROM_LOC + SIZE_OF_INDEX_EEPROM

  ' header offset
  IN_USE_INDICATOR_OFFSET = 0
  RECORDS_USED_OFFSET = 4
  MAX_RECORDS_OFFSET = 5

  MAX_NAME_SIZE = 32
  MAX_PHONE_NUMBER_SIZE = 10
  MAX_SMS_SIZE = 140
  RX_LARGER_THAN_EXPECTED_SIZE = 20
  ' phoneType enumeration
  #0, LAND_LINE_PHONE, CELL_PHONE, OTHER_PHONE
  
  IN_USE_INDICATOR_VALUE = 150_608 ' if the value at location $8000 doesn't equal this value, then
                                   ' the program will now there isn't valid data in the EEPROM.
                                   
  NETWORK_FOUND_TEXT_SIZE = 8
  OK_TEXT_SIZE = 6
  RING_TEXT_SIZE = 8
  MIN_TEXT_SIZE = 3

  ADC_PARAMETERS = 2
  BATTERY_PARAMETERS = 3
  
  #0, OK_TEXT, NETWORK_FOUND_TEXT, READY_CHARACTER_TEXT, RING_TEXT, NO_CARRIER_TEXT
      POWER_DOWN_TEXT, SMS_SENT_TEXT, ADC_TEXT, BATTERY_VOLTAGE_TEXT, VOLUME_TEXT

  MAX_TEXT_INDEX = BATTERY_VOLTAGE_TEXT
  NUMBER_OF_WATCH_FOR_TEXTS = MAX_TEXT_INDEX + 1
  SMALLER_THAN_EXPECTED_TEXT = NUMBER_OF_WATCH_FOR_TEXTS
  LARGER_THAN_EXPECTED_TEXT = SMALLER_THAN_EXPECTED_TEXT + 1
  
  #1, DIAL_TONE, BUSY_TONE, CONGESTION_TONE, PATH_ACK_TONE, PATH_NOT_AVAILABLE_TONE
      ERROR_SPECIAL_TONE, RINGING_TONE
  #16, GENERAL_BEEP_TONE, POSITIVE_ACK_TONE, NEGATIVE_ACK_TONE, INDIAN_DIAL_TONE
       AMERICAN_DIAL_TONE
         
VAR

  long networkStatusPin, rxToFonaPin, txFromFonaPin, ringIndicatorPin
  long keyPin, powerStatusPin, resetPin, fonaBaud
  long inUseValue

  byte recordsInEeprom
  byte rxBuffer[MAX_SMS_SIZE + 1]
  
OBJ

  Pst : "Parallax Serial TerminalDat"
  Fona : "Parallax Serial Terminal256"
  Eeprom : "dwd_PropellerEeprom"
  
PUB Start(networkStatus, rxToFona, txFromFona, ringIndicator, key, powerStatus, reset, baud)

  longmove(@networkStatusPin, @networkStatus, 8)

  if inUseValue <> IN_USE_INDICATOR_VALUE
    CheckEeprom
    
  Fona.StartRxTx(txFromFona, rxToFona, 0, baud)

  result := recordsInEeprom
  
PRI CheckEeprom

  Eeprom.ToRam(@result, @result + LONG_SIZE - 1, HEADER_EEPROM_LOC + IN_USE_INDICATOR_OFFSET)
  Pst.str(string(11, 13, "Checking EEPROM for previous data."))  
  Pst.str(string(11, 13, "The long at $"))
  Pst.Hex(HEADER_EEPROM_LOC + IN_USE_INDICATOR_OFFSET, 4)
  Pst.str(string(" = "))
  Pst.Dec(result)
  Pst.str(string(11, 13, "The expected value was "))
  Pst.Dec(IN_USE_INDICATOR_VALUE)
  Pst.Char(".")
  if result == IN_USE_INDICATOR_VALUE
    Eeprom.ToRam(@recordsInEeprom, @recordsInEeprom, HEADER_EEPROM_LOC + RECORDS_USED_OFFSET)
    Pst.str(string(11, 13, "It appears the upper EEPROM has previously been initalized."))
    Pst.str(string(11, 13, "(read from EEPROM) recordsInEeprom = "))
    Pst.Dec(recordsInEeprom)  
    case recordsInEeprom
      0..MAX_NUMBER_OF_RECORDS:
        Pst.str(string(11, 13, "Some values in upper EEPROM will now be saved."))
        Pst.str(string(11, 13, "to lower EEPROM."))
        DisplayRecordNames
      other:
        SetupEeprom
  else
    Pst.str(string(11, 13, "It appears the upper EEPROM has not been initalized."))
    SetupEeprom
    
  inUseValue := IN_USE_INDICATOR_VALUE      
  Eeprom.FromRam(@inUseValue, @inUseValue + LONG_SIZE - 1, @inUseValue)
  Eeprom.FromRam(@recordsInEeprom, @recordsInEeprom, @recordsInEeprom)
  Eeprom.FromRam(@recordsInEeprom, @recordsInEeprom, HEADER_EEPROM_LOC + RECORDS_USED_OFFSET)
  
PRI SetupEeprom

  Pst.str(string(11, 13, "The program will now initialize the EEPROM"))
  Pst.str(string(11, 13, "in preparation of storing phone numbers and"))
  Pst.str(string(11, 13, "othere data to the EEPROM."))  
  Pst.str(string(11, 13, "Stop this program now if you do not want"))
  Pst.str(string(11, 13, "the upper EEPROM to be overwritten."))
  PressToContinue

  result := FIRST_RECORD_EEPROM_LOC
  Eeprom.FromRam(@result, @result + INDEX_ELEMENT_SIZE - 1, INDEX_EEPROM_LOC)
  ' index #0 will now point to the first record
       
PUB InitFona(attempts)
'' The FONA will be turn on if it is not already on.
'' This method returns -1 if a problem occurred
'' while initializing FONA.
'' This method returns 1 if FONA was successfully
'' initialized.

  ifnot powerState
    SetPower(1, attempts)

  ifnot powerState
    Pst.str(string(7, 11, 13, "Fona Failed to Initialize", 7))
    waitcnt(clkfreq * 2 + cnt)
    return -1

  Fona.RxFlush

  repeat attempts
    Fona.Str(@atText)
    result := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)

    if result <> OK_TEXT
      Pst.str(string(11, 13, "Error"))
      Pst.str(string(11, 13, "OK not received."))
      waitcnt(clkfreq * 2 + cnt)   
      return

  repeat attempts
    Fona.Str(@noEchoText)
    result := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)   
    if result == OK_TEXT
      Pst.str(string(11, 13, "Serial Echo Sucessfully Turned Off"))
      result := 1
      quit
    else
      Pst.str(string(7, 11, 13, "Echo Off CheckForOk Error", 7))

PUB CheckNetworkPin | timer

  result := CheckOnState 
  ifnot result
    result := FONA_OFF_NETWORK 
    return

  repeat while ina[networkStatusPin]

  timer := -cnt

  repeat until ina[networkStatusPin]

  timer += cnt

  timer /= MILLISECOND

  if timer < NETWORK_GPRS_DATA_ACTIVE * 12 / 10
    result := GPRS_DATA_ACTIVE_NETWORK
  elseif timer < NETWORK_NO_CONNECTION * 12 / 10
    result := NO_CONNECTION_NETWORK
  else
    result := READY_NETWORK 
   
  
{PUB CheckNetworkOld
'' Returns the number of characters in "networkFoundText"
'' with successs or returns -1 if a timeout occurs.

  result := LookForTextInBuffer(@networkFoundText, )
                                                    }
PUB CheckOnState

  result := ina[powerStatusPin]
  powerState := result

PUB CheckAdc(modePtr)
'' "modePtr" should point to two consecutive longs.

  result := CheckForInput(ADC_TEXT, ADC_TEXT, COMMAND_TIMEOUT, modePtr, ADC_PARAMETERS)
  if result <> ADC_TEXT
    result := -1
    
PUB CheckBattery(modePtr)
'' "modePtr" should point to three consecutive longs.
'' The charge mode will be written to the first long,
'' the charge percent will be written to the second
'' long and the voltage in millivolts will be written
'' to the third long.

  result := CheckForInput(BATTERY_VOLTAGE_TEXT, BATTERY_VOLTAGE_TEXT, COMMAND_TIMEOUT, modePtr, BATTERY_PARAMETERS)
  if result <> BATTERY_VOLTAGE_TEXT
    result := -1
    
PUB SetPower(state, attempts) | attemptCount

  attemptCount := 0
  result := CheckOnState
  if result == state
    return
  else
    attempts := 0
    repeat 
      dira[keyPin] := 1
      waitcnt(clkfreq * 2 + cnt)
      dira[keyPin] := 0
      attemptCount++
      waitcnt(clkfreq / 2 + cnt)
      result := CheckOnState
      if result <> state
        Pst.str(string(11, 13, "Failed Power Toggle"))
        waitcnt(clkfreq * 2 + cnt)
    while attemptCount < attempts    

PUB CheckForInput(firstExpectedInput, lastExpectedInput, timeoutInterval, parameterPtr, {
} parameters) : watchForIndex | bufferIndex, localSize
'' Checks for received text.
'' Incoming text is saved to "rxBuffer."
'' The text is then compared it with a variety
'' of possible messages.

  localSize := Fona.RxCount
  bufferIndex := 0
  
  if localSize => RX_LARGER_THAN_EXPECTED_SIZE
    watchForIndex := LARGER_THAN_EXPECTED_TEXT
  elseif localSize < MIN_TEXT_SIZE 
    watchForIndex := SMALLER_THAN_EXPECTED_TEXT
  else 'if localSize => MIN_TEXT_SIZE
    repeat 'localSize
      rxBuffer[bufferIndex++] := RxTime(timeoutInterval)
    while rxBuffer[bufferIndex - 1] <> $FF and bufferIndex =< MAX_SMS_SIZE
    ' The present loop will receive characters which arrived after the
    ' RxCheck call.
       
    bufferIndex--
    
    if rxBuffer[bufferIndex] == $FF
      rxBuffer[bufferIndex] := 0
    else
      rxBuffer[++bufferIndex] := 0
      Pst.str(string(7, 11, 13, "Warning Full Rx Buffer", 7))
      
    repeat watchForIndex from firstExpectedInput to lastExpectedInput
      localSize := LookForTextInBuffer(FindString(@okText, watchForIndex), @rxBuffer, parameterPtr, parameters)
      if localSize > 0
        Pst.str(string(11, 13, "Expected Input Received"))
        return

       
PUB Dial(namePtr, numberPtr)

  Pst.str(string(11, 13, "Calling ")) 
  if namePtr
    Pst.Char(QUOTE)   
    Pst.str(namePtr)
    Pst.Char(".")
    Pst.Char(QUOTE)
  else
    Pst.str(string("unknown name."))  

  Pst.str(string(11, 13, "At number ", QUOTE)) 
  Pst.str(numberPtr)
  Pst.Char(QUOTE)

  BothStr(@dialNumberText)
  BothStr(numberPtr)
  BothChar(";")
  BothChar($0D)
  Fona.Char($0A)

  result := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)

  if result <> OK_TEXT  
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "There was a problem when Fona attempted to dial."))
    Pst.str(string(11, 13, "Hanging up just in case it's needed.")) 
    '** hangup?
    HangupPhone
    return
    
  {result := CheckOk
  if result == -1
    Pst.str(string(11, 13, "Timeout Error"))
    Pst.str(string(11, 13, "The Fona was not dialed."))
    return   }
 {
  BothStr(@textModeText)
  result := CheckForOkWithFlush(COMMAND_TIMEOUT)

  ifnot result
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "The Fona was not dialed."))
    return
  }
  {result := CheckOk
  if result == -1
    Pst.str(string(11, 13, "Timeout Error"))
    Pst.str(string(11, 13, "The Fona was not dialed."))
    return       }

PUB SendText(namePtr, numberPtr, textPtr)

  Pst.str(string(11, 13, "Sending text to ")) 
  if namePtr
    Pst.Char(QUOTE)   
    Pst.str(namePtr)
    Pst.Char(".")
    Pst.Char(QUOTE)
  else
    Pst.str(string("an unknown name."))  

  Pst.str(string(11, 13, "At number ", QUOTE)) 
  Pst.str(numberPtr)
  Pst.Char(QUOTE)

  BothStr(@textModeText)

  result := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)
  
  if result <> OK_TEXT
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "No message was sent."))
    return
  
  
  {result := CheckForOkWithFlush(COMMAND_TIMEOUT)

  ifnot result
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "No message was sent."))
    return
    
  result := CheckOk
  if result == -1
    Pst.str(string(11, 13, "Timeout Error"))
    Pst.str(string(11, 13, "The Fona was not dialed."))
    result -= 10
    return }

  BothStr(@textNumberText)
  BothStr(numberPtr)
  BothChar(QUOTE)
  BothChar($0D)
  Fona.Char($0A)
  result := CheckForInput(READY_CHARACTER_TEXT, READY_CHARACTER_TEXT, COMMAND_TIMEOUT, 0, 0)
  
  if result <> READY_CHARACTER_TEXT
    Pst.str(string(11, 13, "Error, no ", QUOTE, ">", QUOTE, " character received."))
    Pst.str(string(11, 13, "No message was sent."))
    Fona.str(@endOfFile)
    'Fona.RxFlush
    return
  
  'result := CheckStringRx(@readyForSmsText, COMMAND_TIMEOUT)

  {ifnot result
    Pst.str(string(11, 13, "Error, no ", QUOTE, ">", QUOTE, " character received."))
    Pst.str(string(11, 13, "No message was sent."))
    Fona.str(@endOfFile)
    Fona.RxFlush
    return
    
  if result < 0
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "Text Aborted"))
    Serial.Char(13)
    Serial.Char(endOfFile)
    result -= 20
    return    }

  BothStr(textPtr)
 
  Fona.str(@endOfFile)

  

  repeat 2
    result := CheckForInput(OK_TEXT, OK_TEXT, SEND_SMS_TIMEOUT, 0, 0) 
    if result == OK_TEXT
      quit
      
  if result == OK_TEXT
    Pst.str(string(11, 13, "Message was sent."))  
  else
    Pst.str(string(7, 11, 13, "Message may not have been sent.", 7))

'PRI CommonReadCommands
'' Commands used to read single messages and all messages.

PUB NumberOfTextMessages : messagesExpected | localCharacter, parameterIndex, newlineCount, characterIndex, {
} linesExpected, tempValue

  Pst.str(string(11, 13, "Finding Number of Text Messages"))

  BothStr(@textModeText)

  tempValue := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)
  
  if tempValue <> OK_TEXT
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "No OK after textModeText."))       
    return
                 
  BothStr(@preferedSmsStorageText)

  parameterIndex := 0
  newlineCount := 0
  characterIndex := 0
  linesExpected := 4 
  messagesExpected := 0
  
  repeat
    localCharacter := RxTime(COMMAND_TIMEOUT)
    characterIndex++
    safeTx(localCharacter)
    if localCharacter == -1
      Pst.str(string(7, 11, 13, "Error"))
      Pst.str(string(11, 13, "Timeout occurred while reading text messages.", 7))
      quit 
    elseif localCharacter == "," and newlineCount == 1
      case ++parameterIndex
        1:
          Pst.str(string(11, 13, "Number of Messages: "))
        2:
          Pst.str(string(11, 13, "Storage Spots: "))
    elseif parameterIndex == 1
      case localCharacter 
        "0".."9":
          messagesExpected *=10
          messagesExpected += localCharacter - "0"
             
  until newlineCount == linesExpected 
   
PUB ReadTextMessages : validMessageCount | messagesExpected, messageIndex

  Pst.str(string(11, 13, "Reading All Text Messages"))

  messagesExpected := NumberOfTextMessages
 
  Pst.str(string(11, 13, "Reading "))
  Pst.Dec(messagesExpected)
  Pst.str(string(" Messages"))

  messageIndex := 0
  repeat until validMessageCount == messagesExpected
    validMessageCount += ReadTextMessage(messageIndex++)
   
PUB ReadTextMessage(messageId) | localCharacter, parameterIndex, newlineCount, characterIndex, {
} linesExpected

  Pst.str(string(11, 13, "Reading SMS #"))
  Pst.Dec(messageId)
  
  BothStr(@textModeText)

  result := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)
  
  if result <> OK_TEXT
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "No message was sent."))
    return

  BothStr(@showSmsParamText)
  result := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)
  
  if result <> OK_TEXT
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "No OK after showSmsParamText."))
    return
    
  BothStr(@readSmsText)
  BothDec(messageID)
  BothChar($0D)
  Fona.Char($0A)

  Pst.str(string(11, 13, "FONA's Reply"))
  
  parameterIndex := 0
  newlineCount := 0
  characterIndex := 0
  linesExpected := 2 ' assumes empty slot unless told otherwise
   
  repeat
    localCharacter := RxTime(COMMAND_TIMEOUT)
    characterIndex++
    safeTx(localCharacter)
    if localCharacter == -1
      Pst.str(string(7, 11, 13, "Error"))
      Pst.str(string(11, 13, "Timeout occurred while reading text message.", 7))
      quit
    elseif newlineCount == 1 and characterIndex == 3 
      case localCharacter
        "O":
          result := 0
        "+":
          linesExpected := 5
          result := 1
        other:
          linesExpected := 5
          result := 0
          Pst.str(string(7, 11, 13, "Error"))
          Pst.str(string(11, 13, "Unexpected character was received.", 7))
    elseif localCharacter == $0A
      newlineCount++
      case newlineCount
        1:
          Pst.str(string(11, 13, "Start of Header: "))
        2:
          Pst.str(string(11, 13, "***** Message Body ***** ", 11, 13))
        3:
          Pst.str(string(11, 13, "************************ ", 11, 13))
          
    elseif localCharacter == "," and newlineCount == 1
      case ++parameterIndex
        1:
          Pst.str(string(11, 13, "Text From Number: "))
        2:
          Pst.str(string(11, 13, "Name: "))
        3:
          Pst.str(string(11, 13, "Date and Time: "))
        5:
          Pst.str(string(11, 13, "Other Stuff: "))
        11:   
          Pst.str(string(11, 13, "Message Size: "))
          
  until newlineCount == linesExpected 
  
PUB DeleteSms(messageId)

  Pst.str(string(11, 13, "Deleting SMS #"))
  Pst.Dec(messageId)
  
  BothStr(@textModeText)

  result := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)
  
  if result <> OK_TEXT
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "No message was deleted."))
    return

  BothStr(@deleteSmsText)
  BothDec(messageID)
  BothChar($0D)
  Fona.Char($0A)

  result := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)
  
  if result <> OK_TEXT
    Pst.str(string(7, 11, 13, "Error"))
    Pst.str(string(11, 13, "Message may not have been deleted.", 7))
    waitcnt(clkfreq * 10 + cnt)
  else
    Pst.str(string(11, 13, "Message deleted."))

PUB DisplayRecordNames  | indexPtr, recordPtr, localCharacter

  
  Pst.str(string(11, 13, "There are presently "))
  Pst.Dec(recordsInEeprom)
  Pst.str(string(" phone records in EEPROM."))

  ifnot recordsInEeprom
    return

  indexPtr := INDEX_EEPROM_LOC
  recordPtr := 0
    
  repeat recordsInEeprom
    Eeprom.ToRam(@recordPtr, @recordPtr + 1, indexPtr) 
    Pst.str(string(11, 13, "# "))
    Pst.Dec(result++)
    Pst.str(string(": ", QUOTE))
    repeat
      Eeprom.ToRam(@localCharacter, @localCharacter, recordPtr++)
      if localCharacter
        Pst.Char(localCharacter)
    while localCharacter
    indexPtr += INDEX_ELEMENT_SIZE

  'Eeprom.FromRam(@inUseValue, @inUseValue + 3, @inUseValue)
  'Eeprom.FromRam(@recordsInEeprom, @recordsInEeprom, @recordsInEeprom)

PUB DisplayRecordNameAndNumber(recordId, namePtr, numberPtr, typePtr)  | indexPtr, {
} recordPtr
'' This method returns type of phone used by this record in EEPROM.
'' The name and number are copied from EEPROM to the locations
'' indicated by "namePtr" and "numberPtr."
'' "typePtr" points to text naming the various types of phones.
'' Data is not written back to "typePtr" as it is with the other
'' two pointers.
'' The phone type is returned with the return value of the method.
'' If "typePtr" is zero, then the phone type will be displayed
'' as a numeric value.

  if recordId => recordsInEeprom
    Pst.str(string(11, 13, "There is not a name and number associated with # "))
    Pst.Dec(recordId)
    Pst.Char(".")
    return -1

  recordPtr := 0
  indexPtr := INDEX_EEPROM_LOC + (INDEX_ELEMENT_SIZE * recordId)

  Eeprom.ToRam(@recordPtr, @recordPtr + INDEX_ELEMENT_SIZE - 1, indexPtr)
  
  result := namePtr
  
  repeat
    Eeprom.ToRam(result, result++, recordPtr++)
  while byte[result - 1]

  result := numberPtr
  
  repeat
    Eeprom.ToRam(result, result++, recordPtr++)
  while byte[result - 1]

  result := 0
  Eeprom.ToRam(@result, @result, recordPtr++)
   
  Pst.str(string(11, 13, "# "))
  Pst.Dec(recordId)
  Pst.str(string(", Name: ", QUOTE))
  Pst.str(namePtr)
  Pst.str(string(QUOTE, ", "))
  Pst.str(numberPtr)
  Pst.str(string(", "))
  if typePtr
    Pst.Str(FindString(typePtr, result))   
  else
    Pst.Dec(result)
     
  'result -= namePtr ' returns number of bytes used by this record in EEPROM
  
PUB SaveNameAndNumber(namePtr, numberPtr, localType) | indexPtr, recordPtr, localSize

  recordPtr := 0

  indexPtr := INDEX_EEPROM_LOC + (INDEX_ELEMENT_SIZE * recordsInEeprom)

  Eeprom.ToRam(@recordPtr, @recordPtr + INDEX_ELEMENT_SIZE - 1, indexPtr)
  
  localSize := strsize(namePtr)

  Eeprom.FromRam(namePtr, namePtr + localSize, recordPtr) ' includes terminating zero
  
  recordPtr += localSize + 1
  localSize := strsize(namePtr)

  Eeprom.FromRam(numberPtr, numberPtr + localSize, recordPtr) ' includes terminating zero
  
  recordPtr += localSize + 1

  Eeprom.FromRam(@localType, @localType, recordPtr)

  recordPtr++
  
  recordsInEeprom++
  indexPtr := INDEX_EEPROM_LOC + (INDEX_ELEMENT_SIZE * recordsInEeprom)

  Eeprom.FromRam(@recordPtr, @recordPtr + INDEX_ELEMENT_SIZE - 1, indexPtr)

  Eeprom.FromRam(@recordsInEeprom, @recordsInEeprom, @recordsInEeprom)
  Eeprom.FromRam(@recordsInEeprom, @recordsInEeprom, HEADER_EEPROM_LOC + RECORDS_USED_OFFSET)

  result := recordsInEeprom

PUB PickupPhone

  BothStr(@pickupPhoneText)
  result := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)
  
  if result <> OK_TEXT
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "Problem with pickup."))  
    waitcnt(clkfreq * 2 + cnt)
    
PUB HangupPhone

  BothStr(@hangupPhoneText)
  result := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)
  
  if result <> OK_TEXT
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "Problem with hangup."))  
    waitcnt(clkfreq * 2 + cnt)
    
PUB SetExternalAudio

  BothStr(@setAudioTypeText)
  BothDec(1)
  BothChar($0D)
  Fona.Char($0A)
  
  result := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)
  
  if result <> OK_TEXT
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "Problem with SetExternalAudio."))
    waitcnt(clkfreq * 2 + cnt)

PUB SetHeadsetAudio

  BothStr(@setAudioTypeText)
  BothDec(0)
  BothChar($0D)
  Fona.Char($0A)
  
  result := CheckForInput(OK_TEXT, OK_TEXT, COMMAND_TIMEOUT, 0, 0)
  
  if result <> OK_TEXT
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "Problem with SetHeadsetAudio."))
    waitcnt(clkfreq * 2 + cnt)

PUB GetVolume | textCode

  BothStr(string("AT+CLVL?"))

  textCode := CheckForInput(VOLUME_TEXT, VOLUME_TEXT, COMMAND_TIMEOUT, @result, 1)
  
  if result <> VOLUME_TEXT
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "Problem with GetVolume."))
    waitcnt(clkfreq * 2 + cnt)
    
PUB SetVolume(newVolume)
  
  BothStr(string("AT+CLVL="))
  BothDec(newVolume) 
  BothChar($0D)
  Fona.Char($0A)

  if result <> OK_TEXT
    Pst.str(string(11, 13, "Error"))
    Pst.str(string(11, 13, "Problem with SetVolume."))
    waitcnt(clkfreq * 2 + cnt)
    
PUB PlayTone(toneId)

  BothStr(string("AT+STTONE="))
  BothDec(1) ' start playing tone
  BothDec(toneId)
  BothDec(1000) ' duration
  BothChar($0D)
  Fona.Char($0A)
       
{PRI RxFromSerial(serialId, serialHoldInterval) | timer, localCharacter, crFlag

  crFlag := 0
  timer := cnt + serialHoldInterval ' make sure empty rx buffers get skipped
  
  repeat
    result := Serial[serialId].RxCount
    if result
      localCharacter := Serial[serialId].CharIn    
      if localCharacter and previousSource <> serialId
        Pst.ClearEnd
        Pst.NewLine
        Pst.Str(FindString(@serialNameText, serialId))
        Pst.Char(">")
        previousSource := serialId
      if localCharacter == 13 
        if crFlag++ ' skip first cariage return 
          Pst.NewLine
      SafeTx(localCharacter)
      timer := cnt
  while cnt - timer < serialHoldInterval
          }
PRI SafeTx(localCharacter)

  if localCharacter => 32 and localCharacter =< "~"
    Pst.Char(localCharacter)
  elseif localCharacter == 0 ' this may need to be changed if monitoring raw data
                             ' "Parallax Serial Terminal" doesn't catch framing errors
                             ' so without this "elseif" line you can end up with a
                             ' bunch of zeros if a line is inactive. 
    return
  else
    Pst.Char("<") 
    Pst.Char("$")
    Pst.Hex(localCharacter, 2)
    Pst.Char(">")

{PUB CheckForOkWithFlush(timeoutInterval) 

  result := CheckForOk(timeoutInterval)
  ifnot result
    Pst.str(string(7, 11, 13, "CheckForOk Error", 7))
    waitcnt(clkfreq / 2 + cnt)
    'Fona.RxFlush
  else
    Pst.str(string(11, 13, "CheckForOk Sucessful"))
         
  Fona.RxFlush
  
PUB CheckForOk(timeoutInterval)
  
  result := CheckStringRx(@okText, timeoutInterval)
  if result <> OK_TEXT_SIZE
    result := 0
  
PUB CheckStringRx(stringPtr, timeoutInterval) | size
'' Returns -1 if a timeout occurs or zero if the
'' wrong character is recieved.

  size := strsize(stringPtr)

  repeat size
    result := RxTime(timeoutInterval)
    if result == -1
      return -1
    elseif result <> byte[stringPtr++]
      Fona.RxFlush
      return 0 
}
PUB RxTime(timeoutInterval) | timer

  timer := cnt
  repeat
    result := Fona.RxCount
  until result or timer - cnt > timeoutInterval

  if result
    result := Fona.CharIn
  else
    result := -1
              
PUB LookForTextInBuffer(stringPtr, bufferPtr, parameterPtr, parameters) : characterCount | size, originalPtr, {
} localCharacter, bufferSize, negativeFlag 
'' The string starting with "textPtr" may start in any location
'' in the incoming stream of data.
'' This method returns the size of "textPtr" if the string is
'' found or it returns -1 if it timesout.

  originalPtr := stringPtr
  bufferSize := strsize(bufferPtr) 
  size := strsize(stringPtr)
  
  repeat bufferSize
    if byte[bufferPtr++] == byte[stringPtr++]
      if ++characterCount == size
        if parameterPtr and parameters
          long[parameterPtr] := 0
          negativeFlag := 0
          repeat
            
            if byte[bufferPtr] => "0" and byte[bufferPtr] =< "9"
              long[parameterPtr] *= 10
              long[parameterPtr] += byte[bufferPtr] - "0"
            elseif byte[bufferPtr] == "-"
              negativeFlag++
            elseif byte[bufferPtr] == ","
              parameters--
              if negativeFlag
                -long[parameterPtr]
              parameterPtr += LONG_SIZE
              long[parameterPtr] := 0
              negativeFlag := 0  
          until byte[bufferPtr++] == 13 or ++characterCount == bufferSize or parameters == 0
          if negativeFlag
            -long[parameterPtr]
        return
    else
      stringPtr := originalPtr
      characterCount := 0  
  
  '-characterCount ' make characterCount negative so calling object knows it ran out of buffer
                  ' This could be useful to indicate a partial word was found but probably not.
                  ' ** think about this

  characterCount := 0
                  
PUB FindString(firstStr, stringIndex)      
'' Finds start address of one string in a list
'' of string. "firstStr" is the address of 
'' string #0 in the list. "stringIndex"
'' indicates which of the strings in the list
'' the method is to find.

  result := firstStr 
  repeat while stringIndex    
    repeat while byte[result++]  
    stringIndex--
    
PUB PressToContinue
  
  Pst.str(string(11, 13, "Press to continue."))
  repeat
    result := Pst.RxCount
  until result
  Pst.RxFlush

PRI BothStr(localStr)

  Pst.Str(localStr)
  Fona.Str(localStr)
  
PRI BothChar(localCharacter)

  Pst.Char(localCharacter)
  Fona.Char(localCharacter)
  
PRI BothDec(value)

  Pst.Dec(value)
  Fona.Dec(value)

DAT

'  #0, OK_TEXT, NETWORK_FOUND_TEXT, READY_CHARACTER_TEXT, RING_TEXT, NO_CARRIER_TEXT
'      POWER_DOWN_TEXT, SMS_SENT_TEXT, ADC_TEXT, BATTERY_VOLTAGE_TEXT, VOLUME_TEXT
okText                  byte $0D, $0A, "OK", $0D, $0A, 0
networkFoundText        byte $0D, $0A, "860719", 0        ' Partial network ID. This will likely be different for users.
readyForSmsText         byte $0D, $0A, ">", 0
ringText                byte $0D, $0A, "RING", $0D, $0A, 0
noCarrierText           byte $0D, $0A, "NO CARRIER", $0D, $0A, 0
powerDownText           byte $0D, $0A, "NORMAL POWER DOWN", $0D, $0A, 0
smsSentText             byte $0D, $0A, "+CMGS: ", 0
adcText                 byte $0D, $0A, "+CADC: ", 0
batteryVoltageText      byte $0D, $0A, "+CBC: ", 0
volumeText              byte $0D, $0A, "+CLVL: ", 0

atText                  byte "AT", $0D, $0A, 0
noEchoText              byte "ATE0", $0D, $0A, 0
checkBatteryText        byte "AT+CBC", $0D, $0A, 0
powerState              byte 0

textModeText            byte "AT+CMGF=1", $0D, $0A, 0
showSmsParamText        byte "AT+CSDH=1", $0D, $0A, 0
preferedSmsStorageText  byte "AT+CPMS?", $0D, $0A, 0 
ringWithSmsText         byte "AT+CFRGRI=1", $0D, $0A, 0
pickupPhoneText         byte "ATA", $0D, $0A, 0   
hangupPhoneText         byte "ATH0", $0D, $0A, 0   
setAudioTypeText        byte "AT+CHFA=", 0

textNumberText          byte "AT+CMGS=", QUOTE, 0
dialNumberText          byte "ATD", 0
deleteSmsText           byte "AT+CMGD=", 0
readSmsText             byte "AT+CMGR=", 0 
textReadCmdsText        byte "REC UNREAD", 0
                        byte "REC READ", 0
                        byte "STO UNSENT", 0
                        byte "STO SENT", 0

smsStorageTypesText     byte "SM", 0  'SIM storage
                        byte "ME", 0  'Phone message storage
                        byte "SM_P", 0  'SM message storage preferred
                        byte "ME_P", 0  ' message storage preferred
                        byte "MT", 0  'SM or ME message storage (SM preferred)
                        


                   
endOfFile               byte $0D, $0A, $0D, $0A, $1A ' control z
 
'serialNameText          byte "FONA", 0, "Ard", 0, "FromTerm", 0, "ToTerm", 0
'previousSource          byte 255
    