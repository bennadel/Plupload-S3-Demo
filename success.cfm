<cfscript>
	

	// Include our ColdFusion 9 -> ColdFusion 10 migration script so 
	// that I can work on this at home (CF10) and in the office (CF9).
	include "cf10-migration.cfm";

	// Include the Amazon Web Service (AWS) S3 credentials.
	include "aws-credentials.cfm";


	// ------------------------------------------------------ //
	// ------------------------------------------------------ //


	// We are expecting the key of the uploaded resource. 
	// --
	// NOTE: This values will NOT start with a leading slash.
	param name="url.key" type="string";

	// Since the key may have characters that required url-encoding,
	// we have to re-encode the key or our signature may not match.
	urlEncodedKey = urlEncodedFormat( url.key );

	// Now that we have the resource, we can construct a full URL
	// and generate a pre-signed, authorized URL.
	resource = ( "/" & aws.bucket & "/" & urlEncodedKey );

	// The expiration is defined as the number of seconds since
	// epoch - as such, we need to figure out what our local timezone
	// epoch is.
	localEpoch = dateConvert( "utc2local", "1970/01/01" );

	// The resource will expire in +1 day.
	expiration = dateDiff( "s", localEpoch, ( now() + 1 ) );

	// Build up the content of the signature (excluding Content-MD5
	// and the mime-type).
	stringToSignParts = [
		"GET",
		"",
		"",
		expiration,
		resource
	];

	stringToSign = arrayToList( stringToSignParts, chr( 10 ) );

	// Generate the signature as a Base64-encoded string.
	// NOTE: Hmac() function was added in ColdFusion 10.
	signature = binaryEncode(
		binaryDecode(
			hmac( stringToSign, aws.secretKey, "HmacSHA1", "utf-8" ),
			"hex"
		),
		"base64"
	);

	// Prepare the signature for use in a URL (to make sure none of
	// the characters get transported improperly).
	urlEncodedSignature = urlEncodedFormat( signature );


	// ------------------------------------------------------ //
	// ------------------------------------------------------ //
	

	// Direct to the pre-signed URL.
	location( 
		url = "https://s3.amazonaws.com#resource#?AWSAccessKeyId=#aws.accessID#&Expires=#expiration#&Signature=#urlEncodedSignature#", 
		addToken = false 
	);


</cfscript>