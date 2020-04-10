'
' http://www.microsoft.com/downloads/en/details.aspx?FamilyID=860ee43a-a843-462f-abb5-ff88ea5896f6&displaylang=en
'

Dim store
Set store = CreateObject("CAPICOM.Store")
store.Open ,,2 

MsgBox "Begin Cert Store cleanup"

Dim cert
For Each cert in store.Certificates
    If cert.HasPrivateKey And Not IsNull(cert.PrivateKey) Then
        Dim privateKey
        Set privateKey = cert.PrivateKey
	If privateKey.IsHardwareDevice And privateKey.IsRemovable And Not privateKey.IsAccessible Then
	    cert.Display
	    ' store.Remove cert
	End If
    End If
Next

MsgBox "End of Cert Store cleanup"
