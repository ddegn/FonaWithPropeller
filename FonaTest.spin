DAT programName         byte "FonaTest", 0
CON
{  
  
}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MILLISECOND   = CLK_FREQ / 1_000
  MICROSECOND   = CLK_FREQ / 1_000_000

CON '' Fona Pins

  NETWORK_STATUS = 21
  RX_TO_FONA = 22
  TX_FROM_FONA = 23
  RING_INDICATOR = 24
  KEY = 25
  POWER_STATUS = 26
  RESET = 27

CON '' Other Fona

  FONA_BAUD = 4_800 '115_200

  CHECK_BATTERY_INTERVAL = MILLISECOND * 20_000
  
CON

  SCALED_MULTIPLIER = 10_000
  SCALED_DECIMAL_PLACES = 4


  ' activeMode enumeration
  #0, UXOURIOUS_TERMINAL_MODE, TERMINAL_MODE, UXOURIOUS_PORTABLE_MODE, PORTABLE_MODE

  ' subMode enumeration
  #0, WHICH_PHONE, TEXT_OR_VOICE, WHICH_TEXT

  ' activePhone enumeration
  #0, CHRISTINA_CELL, CHRISTINA_HOME, CHRISTINA_WORD

  MAX_PHONE_INDEX = CHRISTINA_WORD
  NUMBER_OF_PHONES = MAX_PHONE_INDEX + 1

  ' phoneType enumeration
  #0, LAND_LINE, CELL_LINE

  TEXT_MESSAGES = 4
  MAX_MESSAGE_INDEX = TEXT_MESSAGES - 1
  
  QUOTE = 34

VAR

  long axisDelay[2], xIndex, yIndex, xSquared, ySquared
  long rSquared, previousY
  long fastAtNextSlow, nextSlow, nextSlowSquared
  long fastStepsPerSlow, lastStep[2]
  long fullSpeedSteps, decelSteps
  long lastAccel, activeAccel[2]
  long stepState[2], lastHalfStep[2], lastAccelCnt
  long previousCnt, newCnt, differenceCnt
  long missedHalfCount[2], pLastHalfStep[2], pLastStep[2]
  long previousBatteryTime
  long batteryMode, batteryPercent, batteryMv
  long adcMode, adcValue
  
  byte networkState
  byte recordsInEeprom
  byte nameBuffer[Fona#MAX_NAME_SIZE + 1]
  byte numberBuffer[Fona#MAX_PHONE_NUMBER_SIZE + 1]
  byte phoneType
  byte smsBuffer[Fona#MAX_SMS_SIZE + 1]
  byte volume, validSmsCount
  
DAT

activeMode              byte UXOURIOUS_TERMINAL_MODE
subMode                 byte WHICH_PHONE
activePhone             byte CHRISTINA_CELL

OBJ

  Header : "HeaderFona"
  Pst : "Parallax Serial TerminalDat"
  Format : "StrFmt"
  'Sd[1]: "SdSmall" 
  Fona : "FonaMethods"
 
PUB Setup

  previousBatteryTime := cnt + CHECK_BATTERY_INTERVAL

  Pst.Start(115_200)
 
  repeat
    result := Pst.RxCount
    Pst.str(string(11, 13, "Press any key to continue starting program."))
    waitcnt(clkfreq / 2 + cnt)
  until result
  Pst.RxFlush

  recordsInEeprom := Fona.Start(NETWORK_STATUS, RX_TO_FONA, TX_FROM_FONA, RING_INDICATOR, {
  } KEY, POWER_STATUS, RESET, FONA_BAUD)

  Fona.PressToContinue
  
  Fona.InitFona(3)
  
  waitcnt(clkfreq / 4 + cnt) 
  'Pst.Clear

  networkState := Fona.CheckNetworkPin

  Pst.Str(string(11, 13, "networkState = "))
  Pst.Dec(networkState)

  Pst.str(string(11, 13))
  Pst.str(Fona.FindString(@networkStateText, networkState)) 

  Fona.PressToContinue
  'waitcnt(clkfreq * 2 + cnt) 
  
  Pst.Clear

  MainLoop

PUB MainLoop

  repeat
    Pst.Home
    DisplayHeading
    CheckForInput
    MainMenu    
    Pst.str(string(11, 13))
    Pst.str(Fona.FindString(@networkStateText, networkState)) 

PUB DisplayHeading

  Pst.Str(string(11, 13, "FONA Demo Program"))
  DisplayBattery
  
PUB MainMenu

  Pst.Str(string(11, 13, "Press ", QUOTE, "S", QUOTE, " to Show names in phonebook.")) 
  Pst.Str(string(11, 13, "Press ", QUOTE, "#", QUOTE, " to display names and phone numbers in phonebook.")) 
  Pst.Str(string(11, 13, "Press ", QUOTE, "a", QUOTE, " to check ADC.")) 
  Pst.Str(string(11, 13, "Press ", QUOTE, "b", QUOTE, " to check Battery charge.")) 
  Pst.Str(string(11, 13, "Press ", QUOTE, "E", QUOTE, " to Enter new name and number."))
  'Pst.Str(string(11, 13, "Press ", QUOTE, "n", QUOTE, " to get Network status."))
  Pst.Str(string(11, 13, "Press ", QUOTE, "v", QUOTE, " to set audio Volume."))
  Pst.Str(string(11, 13, "Press ", QUOTE, "V", QUOTE, " to get audio Volume."))    
  Pst.Str(string(11, 13, "Press ", QUOTE, "H", QUOTE, " to set Headphone audio."))    
  Pst.Str(string(11, 13, "Press ", QUOTE, "e", QUOTE, " to set Extermal audio."))    
  Pst.Str(string(11, 13, "Press ", QUOTE, "T", QUOTE, " to play audio Tone."))    
  Pst.Str(string(11, 13, "Press ", QUOTE, "f", QUOTE, " to tune FM Radio."))    
  Pst.Str(string(11, 13, "Press ", QUOTE, "F", QUOTE, " to turn off FM."))    
  Pst.Str(string(11, 13, "Press ", QUOTE, "P", QUOTE, " Pwm/buzzer out."))    
  Pst.Str(string(11, 13, "Press ", QUOTE, "c", QUOTE, " to place a voice Call."))
  Pst.Str(string(11, 13, "Press ", QUOTE, "p", QUOTE, " to Pick up phone."))
  Pst.Str(string(11, 13, "Press ", QUOTE, "h", QUOTE, " to Hang up phone."))
  Pst.Str(string(11, 13, "Press ", QUOTE, "r", QUOTE, " to Read text message."))
  Pst.Str(string(11, 13, "Press ", QUOTE, "N", QUOTE, " to get Number of text messages."))
  Pst.Str(string(11, 13, "Press ", QUOTE, "R", QUOTE, " to Read all text messages."))
  Pst.Str(string(11, 13, "Press ", QUOTE, "d", QUOTE, " to Delete SMS #.")) 
  Pst.Str(string(11, 13, "Press ", QUOTE, "s", QUOTE, " to send a text message."))
  
  Pst.Char(11)
  Pst.Char(13)
  Pst.ClearBelow
  result := Pst.RxCount

  if result
    CheckInputMain
    
PUB CheckInputMain | maxIndex, tempValue

  tempValue := Pst.CharIn
  
  case tempValue
    "S": 
      Fona.DisplayRecordNames
    "#":
      Pst.Str(string(11, 13, "Show Phonebook"))
      ListAllRecords
    "a":
      Fona.CheckAdc(@adcMode)
      DisplayAdc
    "b":
      Fona.CheckBattery(@batteryMode)
      DisplayBattery
    "E": 
      NewRecord
    '"n":
      'GetNetworkStatus
    "v":
      SetVolume
    "V":
      volume := Fona.GetVolume
    "H":
      Fona.SetHeadsetAudio
    "e":
      Fona.SetExternalAudio
    "T":
      PlayTone
    "f":
      SetStation
    "F":
      RadioOff
    "P":
      Buzzer
    "c": 
      VoiceCall 
    "p": 
      Pst.Str(string(11, 13, "Answer Call"))
      Fona.PickupPhone
    "h":
      Pst.Str(string(11, 13, "Hang Up"))
      Fona.HangupPhone
    "r":
      ReadText
    "N":
      NumberOfSms
    "R": 
      Pst.Str(string(11, 13, "Read Text Messages"))
      Fona.ReadTextMessages
    "d":
      DeleteSms
    "s": 
      SendText
    
      
    other:
      Pst.Str(string(11, 13, "Not a valid entry.")) 

PUB DisplayAdc

  if adcMode
    Pst.Str(string(11, 13, "ADC Voltage = "))
    DecPoint(adcValue, 3)
    Pst.Char(" ")
    Pst.Char("V")
  else
    Pst.Str(string(11, 13, "ADC Data Not Valid"))
        
PRI DisplayBattery

  Pst.Str(string(11, 13, "Battery "))
  Pst.str(Fona.FindString(@batteryModeText, batteryMode))    
  Pst.Str(string(" Charging"))
  Pst.Str(string(11, 13, "Charge Left: "))
  Pst.Dec(batteryPercent)
  Pst.Char("%")
  Pst.Str(string(11, 13, "Voltage = "))
  DecPoint(batteryMv, 3)
  Pst.Char(" ")
  Pst.Char("V")
  
PUB NewRecord | localType

  Pst.str(string(11, 13, "There are presently "))
  Pst.Dec(recordsInEeprom)
  Pst.str(string(" phone records in EEPROM."))

  Pst.Str(string(11, 13, "Please enter the name of the next record."))
  Pst.StrIn(@nameBuffer)
  Pst.Str(string(11, 13, "You entered ", QUOTE))
  Pst.Str(@nameBuffer)
  Pst.Str(string(QUOTE, 11, 13, "Is this correct?"))
  Pst.Str(string(11, 13, "Press ", QUOTE, "y", QUOTE, " if this name was entered correctly."))
  Pst.Str(string(11, 13, "Press any other key to disgard entry."))

  result := Pst.CharIn
  case result
    "y", "Y":
      Pst.Str(string(11, 13, "Entry was accepted."))
    other:
      Pst.Str(string(11, 13, "disgarding entry."))
      Pst.Str(string(11, 13, "Returning to main menu."))
      return
  Pst.Str(string(11, 13, "Please enter the number for the record named ", QUOTE))
  Pst.Str(@nameBuffer)
  Pst.Str(string(".", QUOTE))
  Pst.Str(string(11, 13, "Enter the numbers only. Don't enter dashes or other"))
  Pst.Str(string(11, 13, "non-numeric characters."))
   
  Pst.StrIn(@numberBuffer)
  Pst.Str(string(11, 13, "You entered ", QUOTE))
  Pst.Str(@numberBuffer)
  Pst.Str(string(QUOTE, 11, 13, "Is this correct?"))
  Pst.Str(string(11, 13, "Press ", QUOTE, "y", QUOTE, " if this number was entered correctly."))
  Pst.Str(string(11, 13, "Press any other key to disgard entry."))

  result := Pst.CharIn
  case result
    "y", "Y":
      Pst.Str(string(11, 13, "Entry was accepted."))
    other:
      Pst.Str(string(11, 13, "disgarding entry."))
      Pst.Str(string(11, 13, "Returning to main menu."))
      return


  
  Pst.Str(string(11, 13, "Please enter a number from ", QUOTE))
  Pst.Dec(LAND_LINE_PHONE)
  Pst.Str(string(QUOTE, " to ", QUOTE))
  Pst.Dec(OTHER_PHONE)
  Pst.Str(string(QUOTE, " to indicate the type of phone."))
  repeat result from LAND_LINE_PHONE to OTHER_PHONE
    Pst.Str(string(11, 13))
    Pst.Dec(result)
    Pst.Str(string(") "))
    Pst.Str(Fona.FindString(@phoneTypeText, result))

  localType := Pst.DecIn
  Pst.Str(string(11, 13, "You entered ", QUOTE))
  Pst.Dec(localType) 
  Pst.Str(string(QUOTE, " indicating the type is ", QUOTE))
  Pst.Str(Fona.FindString(@phoneTypeText, localType)) 
  Pst.Str(string(".", QUOTE))
  Pst.Str(string(11, 13, "Is this correct?"))
  Pst.Str(string(11, 13, "Press ", QUOTE, "y", QUOTE, " if the type was entered correctly."))
  Pst.Str(string(11, 13, "Press any other key to disgard entry."))
  
  result := Pst.CharIn
  case result
    "y", "Y":
      Pst.Str(string(11, 13, "Entry was accepted."))
    other:
      Pst.Str(string(11, 13, "disgarding entry."))
      Pst.Str(string(11, 13, "Returning to main menu."))
      return

  recordsInEeprom := SaveNameAndNumber(@nameBuffer, @numberBuffer, localType)
  
  Pst.str(string(11, 13, "There are now "))
  Pst.Dec(recordsInEeprom)
  Pst.str(string(" phone records in EEPROM."))        

'PUB GetNetworkStatus

PUB SetVolume

  Pst.str(string(11, 13, "Please enter volume (0 - 100):"))
  volume := 0 #> Pst.DecIn <# 100
  Pst.str(string(11, 13, "Playing tone #"))
  Pst.Dec(volume)
  Fona.SetVolume(volume)
  
PUB PlayTone

  Pst.str(string(11, 13, "Valid tone numbers are 1 - 8 and 16 - 20."))
  Pst.str(string(11, 13, "Please enter tone number:"))
  result := 1 #> Pst.DecIn <# 20
  Pst.str(string(11, 13, "Playing tone #"))
  Pst.Dec(result)
  Fona.PlayTone(result)
  
PUB SetStation
PUB RadioOff
PUB Buzzer
PUB VoiceCall | inputCharacter, numericInputFlag

  numericInputFlag := 0
  
  ListAllRecords
  Pst.str(string(11, 13, "Enter number corresponding to stored number you"))
  Pst.str(string(11, 13, "wish to call or enter ", QUOTE, "d", QUOTE, " to Dial number."))

  repeat
    inputCharacter := Pst.CharIn
    if inputCharacter => "0" and inputCharacter =< "9"
      result *= 10 
      result += inputCharacter - "0"
      numericInputFlag := 1
    else
      quit

  if numericInputFlag
    Pst.str(string(11, 13, "You entered #"))
    Pst.Dec(result)

    if result => recordsInEeprom
      Pst.str(string(11, 13, "Not a valid option."))
      waitcnt(clkfreq * 2 + cnt) 
      return
      
    Fona.DisplayRecordNameAndNumber(result, @nameBuffer, @numberBuffer, @phoneType)
    Fona.Dial(@nameBuffer, @numberBuffer)

  else  
    case inputCharacter
      "d", "D":
        GetNumber(@numberBuffer)  
        Fona.Dial(0, @numberBuffer)
      other:
        Pst.str(string(11, 13, "Not a valid character."))
        waitcnt(clkfreq * 2 + cnt)

PRI GetNumber(localPtr)

  Pst.str(string(11, 13, "Please enter number followed by enter."))
  Pst.StrInMax(localPtr, Fona#MAX_PHONE_NUMBER_SIZE)
  
PUB ReadText

  Pst.str(string(11, 13, "Please enter message # to read:"))
  result := 1 #> Pst.DecIn <# 30
  Pst.str(string(11, 13, "Reading message #"))
  Pst.Dec(result)
  Fona.ReadTextMessage(result)
  
PUB NumberOfSms

  validSmsCount := NumberOfTextMessages
  Pst.str(string(11, 13, "There are "))
  Pst.Dec(validSmsCount)
  Pst.str(string(" stored text messages."))
  
PUB DeleteSms

  Pst.str(string(11, 13, "Please enter message # to delete (1 - 30):"))
  result := 1 #> Pst.DecIn <# 30
  Pst.str(string(11, 13, "Deleting message #"))
  Pst.Dec(result)
  Fona.DeleteSms(result)
 
PUB SendText | inputCharacter, numericInputFlag    

  numericInputFlag := 0
  
  ListAllRecords
  Pst.str(string(11, 13, "Enter number corresponding to stored number you"))
  Pst.str(string(11, 13, "wish to text or enter ", QUOTE, "d", QUOTE))
  Pst.str(string(" to manually enter number to text."))

  repeat
    inputCharacter := Pst.CharIn
    if inputCharacter => "0" and inputCharacter =< "9"
      result *= 10 
      result += inputCharacter - "0"
      numericInputFlag := 1
    else
      quit

  if numericInputFlag
    Pst.str(string(11, 13, "You entered #"))
    Pst.Dec(result)

    if result => recordsInEeprom
      Pst.str(string(11, 13, "Not a valid option."))
      waitcnt(clkfreq * 2 + cnt) 
      return
      
    Fona.DisplayRecordNameAndNumber(result, @nameBuffer, @numberBuffer, @phoneType)
    'Fona.Dial(@nameBuffer, @numberBuffer)

  else  
    case inputCharacter
      "d", "D":
        GetNumber(@numberBuffer)  
        'Fona.Dial(0, @numberBuffer)
      other:
        Pst.str(string(11, 13, "Not a valid character."))
        waitcnt(clkfreq * 2 + cnt)
        return

  GetTextBody(@smsBuffer)

PUB GetTextBody(textBufferPtr) | characterCount, inputCharacter

  characterCount := 0

  Pst.str(string(11, 13, "Enter Text of Message:", 11, 13))
  
  repeat
    inputCharacter := Pst.CharIn
    if inputCharacter == Pst#BS and characterCount
      characterCount--
      byte[textBufferPtr][characterCount] := 0
      Pst.Char(Pst#BS)
      Pst.Char(11)
    elseif inputCharacter == Pst#BS
      Pst.Char(7)
    elseif inputCharacter == 13
      byte[textBufferPtr][++characterCount] := 0
      Pst.Char(inputCharacter) 
    else
      byte[textBufferPtr][++characterCount] := 0
      Pst.Char(inputCharacter)
      
  while characterCount < Fona#MAX_SMS_SIZE and inputCharacter <> 13
          
PUB CheckForInput

  if cnt - previousBatteryTime > CHECK_BATTERY_INTERVAL
    previousBatteryTime += CHECK_BATTERY_INTERVAL
    
  result := Fona.CheckForInput
  if result
    Pst.Str(string(7, 11, 13, "RING! RING!"))
    Pst.Str(string(11, 13, "Press ", QUOTE, "a", QUOTE, " to Answer call."))   
    Pst.Str(string(11, 13, "Press any other key to return to the main menu."))   
    result := Pst.CharIn
    case result
      "a", "A":
        Pst.Str(string(11, 13, "Answering Phone"))
        AnswerCall
      other:
        Pst.Str(string(11, 13, "Ignoring ring."))
        Pst.Str(string(11, 13, "Returning to main menu."))


PUB SendSavedText(textId)

  if phoneType[activePhone] <> CELL_LINE
    Pst.Str(string(11, 13, "The present active number ", QUOTE))
    Pst.str(Header.FindString(@phoneNameText, activePhone))
    Pst.Str(string(QUOTE, " is not a cell phone."))
    Pst.Str(string(11, 13, "Please select of cell phone to test."))
    return 

  Pst.Str(string(11, 13, "Please select which text message you'd like to send."))
  repeat result from 0 to MAX_MESSAGE_INDEX
    Pst.Dec(result)
    Pst.Str(string(") ", QUOTE))
    Pst.str(Header.FindString(@textMessageText, result))

PUB ListAllRecords

  if recordsInEeprom
    Pst.Str(string(11, 13, "ID#, Name, Phone Number, Type of Phone"))
    maxIndex := recordsInEeprom - 1
    repeat result from 0 to maxIndex
      DisplayRecordNameAndNumber(result, @nameBuffer, @numberBuffer)
  else
    Pst.Str(string(11, 13, "The phonebook is presently empty."))

PUB DecPoint(value, decimalPlaces) | localBuffer[4]

  result := Format.FDec(@localBuffer, value, decimalPlaces + 4, decimalPlaces)
  byte[result] := 0
  Pst.str(@localBuffer)

PUB CatastrophicError(errorPtr)

  Pst.str(@astriskLine)
  Pst.str(string(7, 11, 13, "Error! ", 7))
  Pst.str(errorPtr)
  Pst.str(string(7, 11, 13, "Done! Program Over", 7))
  repeat

{PUB DisplayAxis(localIndex)

  Pst.str(Header.FindString(@axisText, localIndex))
  Pst.str(string("-Axis"))
  
PUB DisplayPhase(localIndex)

  Pst.str(Header.FindString(@phaseText, localIndex))
  Pst.str(string(" phase"))
  
PUB DisplaySpeed(localIndex)

  Pst.str(Header.FindString(@speedText, localIndex))
  
PUB DisplayDirection(localIndex)

  Pst.str(Header.FindString(@directionText, localIndex))
      }
DAT

astriskLine   byte 11, 13, "**************************************************"
              byte "*********************", 0

fastAtRadiusError       byte "||xIndex[localAxis] == radius", 0
accelAxisError          byte "localAxis <> accelAxis", 0
decelAxisError          byte "localAxis <> decelAxis", 0

axisText                byte "X", 0, "Y", 0
speedText               byte "fast", 0, "slow", 0
phaseText               byte "accleration", 0, "full speed", 0, "deceleration", 0
directionText           byte "forward", 0, "reverse", 0

networkStateText        byte "The Fona is off, it's not possible to detect network.", 0
                        byte "The Fona is not connected to a network.", 0
                        byte "The network is ready for voice and text.", 0
                        byte "The network is ready for GPRS data.", 0
'  #0, FONA_OFF_NETWORK, NO_CONNECTION_NETWORK, READY_NETWORK, GPRS_DATA_ACTIVE_NETWORK
  
phoneNumberText         byte "2400000", 0
                        byte "2390000", 0
                        byte "6370000", 0
                        
phoneNameText           byte "Christina Cell", 0
                        byte "Christina Home", 0
                        byte "Christina Work", 0

textMessageText         byte "Hi Chrisina, I love you.", 0
                        byte "Christina you are a beautiful person.", 0
                        byte "Christina would you like to go on a date with me tonight?", 0
                        byte "Yes dear.", 0
'' Make sure and change the constant "TEXT_MESSAGES" if messages are added or removed.                        

phoneTypeText           byte "land line", 0
                        byte "cell phone", 0
                        byte "other phone", 0

batteryModeText         byte "Not", 0       '** check order
                        byte "Currently", 0
                        byte "Finished", 0
                                  