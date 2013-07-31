<cfscript>
	

	// Get the list of functions that the current version of ColdFusion
	// currently implements.
	nativeFunctions = getFunctionList();


	// Migration for hmac() to CF9.
	public string function hmacCF9(
		required string message,
		required string key,
		string algorithm = "HmacSHA1",
		string encoding = "utf-8"
		) {

		// Create the specification for our secret key.
		var secretkeySpec = createObject( "java", "javax.crypto.spec.SecretKeySpec" ).init(
			charsetDecode( key, "utf-8" ),
			javaCast( "string", algorithm )
		);

		// Get an instance of our MAC generator.
		var mac = createObject( "java", "javax.crypto.Mac" ).getInstance(
			javaCast( "string", algorithm )
		);

		// Initialize the Mac with our secret key spec.
		mac.init( secretkeySpec );

		// Hash the input (as a byte array).
		var hashedBytes = mac.doFinal(
			charsetDecode( message, "utf-8" )
		);

		// Return the hashed bytes as Hex since that is how COdlFusion 10
		// will be returning the value.
		return(
			ucase( binaryEncode( hashedBytes, "hex" ) )
		);

	}


	// Check to see if we need to add the migration functions to the
	// local page scope (variables).

	if ( ! structKeyExists( nativeFunctions, "hmac" ) ) {

		hmac = hmacCF9;

	}
	

</cfscript>