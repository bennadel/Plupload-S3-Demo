<cfscript>
	
	// Plupload exmaple: https://github.com/moxiecode/plupload/blob/master/examples/jquery/s3.php
	

	// Include the Amazon Web Service (AWS) S3 credentials.
	include "aws-credentials.cfm";

	// Set up the Success url that Amazon S3 will redirect to if the
	// FORM POST has been submitted successfully.
	// ---
	// NOTE: If the form post fails, Amazon will present an error
	// message - there is no error-based redirect. We'll have to look
	// for this condition in the Plupload error handler.
	successUrl = (
		"http://" & cgi.server_name &
		getDirectoryFromPath( cgi.script_name ) & "success.cfm"
	);

	// The expiration must defined in UCT time. Since the Plupload
	// widget may be on the screen for a good amount of time, 
	// especially if this is a single-page app, we probably need to 
	// put the expiration date into the future a good amount.
	expiration = dateConvert( "local2utc", dateAdd( "d", 1, now() ) );

	// NOTE: When formatting the UTC time, the hours must be in 24-
	// hour time; therefore, make sure to use "HH", not "hh" so that
	// your policy don't expire prematurely.
	policy = {
		"expiration" = (
			dateFormat( expiration, "yyyy-mm-dd" ) & "T" &
			timeFormat( expiration, "HH:mm:ss" ) & "Z"
		),
		"conditions" = [ 
			{
				"bucket" = aws.bucket
			}, 
			{
				"acl" = "public-read"
			},
			//{
			//	"success_action_redirect" = successUrl
			//},
			{
				"success_action_status" = "201 Created"
			},
			[ "starts-with", "$key", "pluploads/" ],
			[ "starts-with", "$Content-Type", "image/" ],
			[ "content-length-range", 0, 10485760 ], // 10mb

			// The following keys are ones that Plupload will inject
			// into the form-post across the various environments.
			[ "starts-with", "$Filename", "pluploads/" ],
			[ "starts-with", "$name", "" ]
		]
	};


	// ------------------------------------------------------ //
	// ------------------------------------------------------ //


	// The policy will be posted along with the FORM post as a
	// hidden form field. Serialize it as JavaScript Object notation.
	serializedPolicy = serializeJson( policy );

	// Remove up the line breaks.
	serializedPolicy = reReplace( serializedPolicy, "[\r\n]+", "", "all" );

	// Encode the policy as Base64 so that it doesn't mess up
	// the form post data at all.
	encodedPolicy = binaryEncode(
		charsetDecode( serializedPolicy, "utf-8" ) ,
		"base64"
	);


	// ------------------------------------------------------ //
	// ------------------------------------------------------ //


	// To make sure that no one tampers with the FORM POST, create
	// hashed message authentication code of the policy content.
	// NOTE: The hmac() function was added in ColdFusion 10.
	hashedPolicy = hmac(
		encodedPolicy,
		aws.secretKey,
		"HmacSHA1",
		"utf-8"
	);

	// Encode the message authentication code in Base64.
	encodedSignature = binaryEncode(
		binaryDecode( hashedPolicy, "hex" ),
		"base64"
	);


</cfscript>


<!--- ----------------------------------------------------- --->
<!--- ----------------------------------------------------- --->


<!--- Reset the output buffer and set the page encoding. --->
<cfcontent type="text/html; charset=utf-8" />

<cfoutput>

	<!doctype html>
	<html>
	<head>
		<meta charset="utf-8" />

		<title>
			Uploading Files To Amazon S3 Using Plupload And ColdFusion
		</title>

		<link rel="stylesheet" type="text/css" href="./assets/css/styles.css"></link>
	</head>
	<body>

		<h1>
			Uploading Files To Amazon S3 Using Plupload And ColdFusion
		</h1>

		<div id="uploader" class="uploader">

			<a id="selectFiles" href="##">

				<span class="label">
					Select Files
				</span>

				<span class="standby">
					Waiting for files...
				</span>

				<span class="progress">
					Uploading - <span class="percent"></span>%
				</span>

			</a>

		</div>


		<!-- Load and initialize scripts. -->
		<script type="text/javascript" src="./assets/jquery/jquery-2.0.3.min.js"></script>
		<script type="text/javascript" src="./assets/plupload/js/plupload.full.js"></script>
		<script type="text/javascript">

			(function( $, plupload ) {


				// Find and cache the DOM elements we'll be interacting with.
				var dom = {
					uploader: $( "##uploader" ),
					percent: $( "##uploader span.percent" )
				};


				var uploader = new plupload.Uploader({

					// Try to load the HTML5 engine and then, if that's 
					// not supported, the Flash fallback engine.
					runtimes: "html5,flash",

					// The upload URL.
					url: 'http://#aws.bucket#.s3.amazonaws.com/',

					// The ID of the drop-zone element.
					drop_element: "uploader",

					// To enable click-to-select-files, you can provide a
					// browse button. We can use the same one as the drop
					// zone.
					browse_button: "selectFiles",

					// For the Flash engine, we have to define the ID of
					// the node into which Pluploader will inject the 
					// <OBJECT> tag for the flash movie.
					container: "uploader",

					// The URL for the SWF file for the Flash upload 
					// engine for browsers that don't support HTML5.
					flash_swf_url: "./assets/plupload/js/plupload.flash.swf",

					//unique_names: true,

					// The name of the form-field that will hold the upload data.
					file_data_name: "file",

					multipart: true,

					multipart_params: {
						"acl": "public-read",
						// "success_action_redirect": "#htmlEditFormat( successUrl )#",
						"success_action_status": "201 Created",
						"key": "pluploads/${filename}",
						"Filename": "pluploads/${filename}",
						"Content-Type": "image/*",
						"AWSAccessKeyId" : "#aws.accessID#",
						"policy": "#encodedPolicy#",
						"signature": "#encodedSignature#"
					},

					max_file_size : "10mb" // 10485760 bytes
				});


				uploader.bind( "Init", handlePluploadInit );
				uploader.bind( "Error", handlePluploadError );
				uploader.bind( "FilesAdded", handlePluploadFilesAdded );
				uploader.bind( "QueueChanged", handlePluploadQueueChanged );
				uploader.bind( "UploadProgress", handlePluploadUploadProgress );
				uploader.bind( "FileUploaded", handlePluploadFileUploaded );
				

				uploader.init();


				function handlePluploadInit( uploader, params ) {


				}


				function handlePluploadError() {
					console.log( "Error" );
					console.dir( arguments );
				}


				function handlePluploadFilesAdded() {

				}


				function handlePluploadQueueChanged( uploader ) {

					if ( uploader.files.length && isNotUploading() ){

						uploader.start();

					}

				}


				function handlePluploadUploadProgress( uploader, file ) {
				}


				function handlePluploadFileUploaded( uploader, file, response ) {
					console.log( "File Uploaded" );
					console.dir( response );
					console.dir( arguments );
				}

				

				// I determine if the upload is currently inactive.
				function isNotUploading() {

					var currentState = uploader.state;

					return( currentState === plupload.STOPPED );

				}


				// I determine if the uploader is currently uploading a
				// file (or if it is inactive).
				function isUploading() {

					var currentState = uploader.state;

					return( currentState === plupload.STARTED );

				}



			})( jQuery, plupload );


		</script>

	</body>
	</html>

</cfoutput>