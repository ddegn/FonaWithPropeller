DAT programName         byte "MonitorFona", 0
CON
{{      

}}
{
  ******* Private Notes *******
  
}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

OBJ

  Pst : "Parallax Serial Terminal"
  Fona : "Parallax Serial Terminal"
  Arduino : "Parallax Serial Terminal"
 
PUB Start

  Pst.Start(115_200)
  InitFona
  
  MonitorFona
  
PRI InitFona

  Fona.StartRxTx(0, -1, 0, 4_800)
  Arduino.StartRxTx(1, -1, 0, 4_800)

PUB MonitorFona | localCharacter, previousSource
'' Monitors Comminication between Arduino and Fona.
'' This method only listens to Fona. It does
'' not pass any data to the Fona.

  previousSource := -1
  repeat
    result := Fona.RxCount
    if result
      if previousSource <> 1
        Pst.Str(string(11, 13, "FONA>"))
        previousSource := 1
      localCharacter := Fona.CharIn    
      SafeTx(localCharacter)
    result := Arduino.RxCount
    if result
      if previousSource <> 2
        Pst.Str(string(11, 13, "Ard>"))
        previousSource := 2
      localCharacter := Arduino.CharIn    
      SafeTx(localCharacter)

PRI SafeTx(localCharacter)

  if localCharacter => 32 and localCharacter =< "~"
    Pst.Char(localCharacter)
  elseif localCharacter == 0
    return
  else
    Pst.Char("<") 
    Pst.Char("$")
    Pst.Hex(localCharacter, 2)
    Pst.Char(">")
