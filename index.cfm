<cfscript>
	

	// Include our ColdFusion 9 -> ColdFusion 10 migration script so 
	// that I can work on this at home (CF10) and in the office (CF9).
	include "cf10-migration.cfm";

	// Include the Amazon Web Service (AWS) S3 credentials.
	include "aws-credentials.cfm";

	// The expiration must defined in UCT time. Since the Plupload
	// widget may be on the screen for a good amount of time, 
	// especially if this is a single-page app, we probably need to 
	// put the expiration date into the future a good amount.
	expiration = dateConvert( "local2utc", dateAdd( "d", 1, now() ) );

	// NOTE: When formatting the UTC time, the hours must be in 24-
	// hour time; therefore, make sure to use "HH", not "hh" so that
	// your policy don't expire prematurely.
	// ---
	// NOTE: We are providing a success_action_status INSTEAD of a 
	// success_action_redirect since we don't want the browser to try
	// and redirect (won't be supported across all Plupload 
	// environments). Instead, we'll get Amazon S3 to return the XML
	// document for the successful upload. Then, we can parse teh 
	// response locally.
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
				"acl" = "private"
			},
			{
				"success_action_status" = "2xx"
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

	// When the policy is being serialized, ColdFusion will try to turn
	// "201" into the number 201. However, we NEED this value to be a
	// STRING. As such, we'll give the policy a non-numeric value and
	// then convert it to the appropriate 201 after serialization.
	serializedPolicy = replace( serializedPolicy, "2xx", "201" );

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

		<ul class="uploads">
			<!--
				Will be populated dynamically with LI/IMG tags by the
				uploader success handler. 
			-->
		</ul>


		<!-- Load and initialize scripts. -->
		<script type="text/javascript" src="./assets/jquery/jquery-2.0.3.min.js"></script>
		<script type="text/javascript" src="./assets/plupload/js/plupload.full.js"></script>
		<script type="text/javascript">

			(function( $, plupload ) {


				// Find and cache the DOM elements we'll be using.
				var dom = {
					uploader: $( "##uploader" ),
					percent: $( "##uploader span.percent" ),
					uploads: $( "ul.uploads" )
				};


				// Instantiate the Plupload uploader. When we do this, 
				// we have to pass in all of the data that the Amazon 
				// S3 policy is going to be expecting. Also, we have 
				// to pass in the policy :)
				var uploader = new plupload.Uploader({

					// Try to load the HTML5 engine and then, if that's
					// not supported, the Flash fallback engine.
					// --
					// NOTE: For Flash to work, you will have to upload
					// the crossdomain.xml file to the root of your 
					// Amazon S3 bucket.
					runtimes: "html5,flash",

					// The upload URL - our Amazon S3 bucket.
					url: "http://#aws.bucket#.s3.amazonaws.com/",

					// The ID of the drop-zone element.
					drop_element: "uploader",

					// To enable click-to-select-files, you can provide
					// a browse button. We can use the same one as the 
					// drop zone.
					browse_button: "selectFiles",

					// For the Flash engine, we have to define the ID 
					// of the node into which Pluploader will inject the 
					// <OBJECT> tag for the flash movie.
					container: "uploader",

					// The URL for the SWF file for the Flash upload 
					// engine for browsers that don't support HTML5.
					flash_swf_url: "./assets/plupload/js/plupload.flash.swf",

					// Needed for the Flash environment to work.
					urlstream_upload: true,

					// NOTE: I couldn't get unique names to work...
					// unique_names: true,

					// The name of the form-field that will hold the 
					// upload data. Amason S3 will expect this form 
					// field to be called, "file".
					file_data_name: "file",

					multipart: true,

					// Pass through all the values needed by the Policy 
					// and the authentication of the request.
					multipart_params: {
						"acl": "private",
						"success_action_status": "201",
						"key": "pluploads/${filename}",
						"Filename": "pluploads/${filename}",
						"Content-Type": "image/*",
						"AWSAccessKeyId" : "#aws.accessID#",
						"policy": "#encodedPolicy#",
						"signature": "#encodedSignature#"
					},

					max_file_size : "10mb" // 10485760 bytes
				});


				// Set up the event handlers for the uploader.
				uploader.bind( "Init", handlePluploadInit );
				uploader.bind( "Error", handlePluploadError );
				uploader.bind( "FilesAdded", handlePluploadFilesAdded );
				uploader.bind( "QueueChanged", handlePluploadQueueChanged );
				uploader.bind( "BeforeUpload", handlePluploadBeforeUpload );
				uploader.bind( "UploadProgress", handlePluploadUploadProgress );
				uploader.bind( "FileUploaded", handlePluploadFileUploaded );
				uploader.bind( "StateChanged", handlePluploadStateChanged );
				
				// Initialize the uploader (it is only after the 
				// initialization is complete that we will know which
				// runtime load: html5 vs. Flash).
				uploader.init();


				// ------------------------------------------ //
				// ------------------------------------------ //


				// I handle the before upload event where the meta data
				// can be edited right before the upload of a specific
				// file, allowing for per-file Amazon S3 settings.
				function handlePluploadBeforeUpload( uploader, file ) {
					
					console.log( "File upload about to start." );

					// Generate a "unique" key based on the file ID
					// that Plupload has assigned. This way, we can
					// create a non-colliding directory, but keep
					// the original file name from the client.
					var uniqueKey = ( "pluploads/" + file.id + "/" + file.name );

					// Update the Key and Filename so that Amazon S3
					// will store the resource with the correct value.
					uploader.settings.multipart_params.key = uniqueKey;
					uploader.settings.multipart_params.Filename = uniqueKey;

				}


				// I handle the init event. At this point, we will know
				// which runtime has loaded, and whether or not drag-
				// drop functionality is supported.
				function handlePluploadInit( uploader, params ) {

					console.log( "Initialization complete." );

					console.log( "Drag-drop supported:", !! uploader.features.dragdrop );

				}


				// I handle any errors raised during uploads.
				function handlePluploadError() {
					
					console.log( "Error during upload." );

				}


				// I handle the files-added event. This is different
				// that the queue-changed event. At this point, we 
				// have an opportunity to reject files from the queue.
				function handlePluploadFilesAdded() {

					console.log( "Files selected." );

				}


				// I handle the queue changed event.
				function handlePluploadQueueChanged( uploader ) {

					console.log( "Files added to queue." );

					if ( uploader.files.length && isNotUploading() ){

						uploader.start();

					}

				}


				// I handle the upload progress event. This gives us
				// the progress of the given file, NOT of the entire
				// upload queue.
				function handlePluploadUploadProgress( uploader, file ) {

					console.log( "Upload progress:", file.percent );

					dom.percent.text( file.percent );

				}


				// I handle the file-uploaded event. At this point, 
				// the resource had been uploaded to Amazon S3 and
				// we can tell OUR SERVER about the event.
				function handlePluploadFileUploaded( uploader, file, response ) {

					var resourceData = parseAmazonResponse( response.response );

					var li = $( "<li><img /></li>" );
					var img = li.find( "img" );

					// When passing the uploaded Key back to the 
					// success page, we have to be sure to fullly
					// encode the key so that it doesn't confuse 
					// any other parts of the normal URL component
					// system (ex. hashes in a filename can be 
					// misinterpreted as the URL hash).
					img.prop(
						"src",
						( "./success.cfm?key=" + encodeURIComponent( resourceData.key ) )
					);

					dom.uploads.prepend( li );

				}


				// I handle the change in state of the uploader.
				function handlePluploadStateChanged( uploader ) {

					if ( isUploading() ) {

						dom.uploader.addClass( "uploading" );

					} else {

						dom.uploader.removeClass( "uploading" );

					}

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


				// When Amazon S3 returns a 201 reponse, it will provide
				// an XML document with the values related to the newly
				// uploaded Resource. This function extracts the two 
				// values: Bucket and Key.
				function parseAmazonResponse( response ) {

					var result = {};
					var pattern = /<(Bucket|Key)>([^<]+)<\/\1>/gi;
					var matches = null;

					while ( matches = pattern.exec( response ) ) {

						var nodeName = matches[ 1 ].toLowerCase();
						var nodeValue = matches[ 2 ];

						result[ nodeName ] = nodeValue;

					}

					return( result );

				}


			})( jQuery, plupload );


		</script>

	</body>
	</html>

</cfoutput>