<cfscript>
	
	// Plupload exmaple: https://github.com/moxiecode/plupload/blob/master/examples/jquery/s3.php
	// Amazon S3 blog post: http://aws.amazon.com/articles/1434?_encoding=UTF8&jiveRedirect=1


	
	policy = {
		"expiration" = "2014-01-01T00:00:00Z",
		"conditions" = [ 
			{
				"bucket" = request.s3.bucket
			}, 
			{
				"acl" = "private"
			},
			{
				"success_action_redirect" = ( "http://" & cgi.server_name & getDirectoryFromPath( cgi.script_name ) & "success.cfm" )
			},
			{
				"success_action_status" = "201"
			},
			[ "content-length-range", 0, 10485760 ],
			[ "starts-with", "$name", "" ],
			[ "starts-with", "$key", "form-uploads/" ],
			[ "starts-with", "$Content-Type", "image/" ],
			[ "starts-with", "$Filename", "" ]
		]
	};


	postPolicy = "";
	postSignature = "";


</cfscript>


<!--- ----------------------------------------------------- --->
<!--- ----------------------------------------------------- --->


<!--- Reset the output buffer and define the character encoding of the page. --->
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
					url: 'http://#request.s3.bucket#.s3.amazonaws.com/',

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

					unique_names: true,

					// The name of the form-field that will hold the upload data.
					file_data_name: "file",

					multipart: true,

					multipart_params: {
						"key": "form-uploads/${filename}",
						"Filename": "${filename}", 		// Adding this to keep consistency across the runtimes.
						"acl": "private",
						"Content-Type": "image/*",
						"success_action_status": "201",
						"AWSAccessKeyId" : "#request.s3.accessID#",
						"policy": "#postPolicy#",
						"signature": "#postSignature#"
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