'
' Download CAPICOM from http://www.microsoft.com/downloads/en/details.aspx?FamilyID=860ee43a-a843-462f-abb5-ff88ea5896f6&displaylang=en
' Install it
' Register it (regsrv32 capicom.dll)
'

Const CAPICOM_LOCAL_MACHINE_STORE = 1
Const CAPICOM_MY_STORE = "My"
Const CAPICOM_STORE_OPEN_READ_ONLY = 0
Const CAPICOM_CERTIFICATE_FIND_TEMPLATE_NAME = 4
Const CRYPT_EXPORTABLE = 1
Const CR_IN_BASE64 = &H1
Const CR_IN_PKCS10 = &H100
Const CR_OUT_BASE64 = &H1
Const CR_OUT_CHAIN = &H100
Const CERT_SYSTEM_STORE_LOCAL_MACHINE = &H20000
Const CRYPT_MACHINE_KEYSET = &H20

Const strTemplate = "Machine"
Const strProviderName = "Microsoft Enhanced Cryptographic Provider v1.0"
Const intKeySize = 1024
Const strTargetCA = "adcs-trial.acme.tld\Root CA"

Dim objStore
Set objStore = CreateObject("CAPICOM.Store")
objStore.Open CAPICOM_LOCAL_MACHINE_STORE, CAPICOM_MY_STORE, CAPICOM_STORE_OPEN_READ_ONLY

Dim bFoundCert : bFoundCert = vbFalse

WScript.Echo "Begin Cert Store enumeration"
WScript.Echo

Dim objCerts : Set objCert = objStore.Certificates
Set objCerts = objCert.Find(CAPICOM_CERTIFICATE_FIND_TEMPLATE_NAME, strTemplate, vbTrue)

Dim objCert
For Each objCert in objCerts
    If objCert.HasPrivateKey And Not IsNull(objCert.PrivateKey) Then
		WScript.Echo "Found certificate " & objCert.SerialNumber & ":"
		WSCript.Echo "   Issuer DN: " & objCert.IssuerName
		WScript.Echo "   Subject DN: " & objCert.SubjectName
		WSCript.Echo "   Not Before: " & objCert.ValidFromDate
		WSCript.Echo "   Not After: " & objCert.ValidToDate
		WScript.Echo
		bFoundCert = vbTrue
    End If
Next

WScript.Echo "End of Cert Store enumeration: found = " & bFoundCert

If Not bFoundCert Then
	WScript.Echo "Starting Auto-Enrollment"
	WScript.Echo

	Dim objCEnroll
	Set objCEnroll = CreateObject("CEnroll.CEnroll")

	objCEnroll.GenKeyFlags = intKeySize * (256*256) + CRYPT_EXPORTABLE
	objCEnroll.UseExistingKeySet = 0
	objCEnroll.addCertTypeToRequest(strTemplate)
	objCEnroll.ProviderName = strProviderName
	objCEnroll.MyStoreFlags = CERT_SYSTEM_STORE_LOCAL_MACHINE
	objCEnroll.RequestStoreFlags = CERT_SYSTEM_STORE_LOCAL_MACHINE
	objCEnroll.ProviderFlags = CRYPT_MACHINE_KEYSET

	Dim strP10
	strP10 = objCEnroll.createPKCS10("CN=Dummy", "1.3.6.1.5.5.7.3.2")
	WScript.Echo "PKCS#10 Request:"
	WScript.Echo strP10

	Dim objCARequest
	Set objCARequest = CreateObject("CertificateAuthority.Request")
	
	Dim intReqFlags
	intReqFlags = CR_IN_BASE64 OR CR_IN_PKCS10
	
	Dim intReqStatus
	intReqStatus = objCARequest.Submit(intReqFlags, strP10, "", strTargetCA)
	WScript.Echo "Request Sent. Status = " & intReqStatus

	Dim strCertificate
	strCertificate = objCARequest.GetCertificate(CR_OUT_BASE64 Or CR_OUT_CHAIN)
	WScript.Echo "Issued Certificate:"
	WScript.Echo strCertificate

	objCEnroll.acceptPKCS7(strCertificate)
	
	WScript.Echo
	WScript.Echo "End of Auto-Enrollment"
End If

