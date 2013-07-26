component
	output = false
	hint = "I define the application settings and event handlers."
	{


	// Define the application settings.
	this.name = hash( getCurrentTemplatePath() );
	this.applicationTimeout = createTimeSpan( 0, 1, 0, 0 );
	this.sessionManagement = false;


	public boolean function onRequestStart( required string script ) {

		// {
		// 	"bucket": "***",
		// 	"accessID": "***",
		// 	"secretKey": "***"
		// }

		var config = fileRead( expandPath( "./s3.config" ) );

		request.s3 = deserializeJson( config );

		return( true );

	}


}