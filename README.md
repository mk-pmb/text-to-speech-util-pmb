
<!--#echo json="package.json" key="name" underline="=" -->
text-to-speech-util-pmb
=======================
<!--/#echo -->

<!--#echo json="package.json" key="description" -->
Pre-load several speech engines and offer to read text submitted via network.
<!--/#echo -->




Voice engine TTS CLI apps
-------------------------

You can find some exe snapshots in the `blobs` branch. Use at your own risk.
If you prefer to compile them yourself, you can find the sources here:

* MS SAPI v1: `tts-cli/serverTtsCli.cs` from
  https://github.com/mk-pmb/msspeechsdk_v011_wine_howto/
* Logox 4: `tts-cli/logox4_cli_simple.cs` from
  https://github.com/mk-pmb/webspeech-util-pmb/


<!--#toc stop="scan" -->



Known issues
------------

* Needs more/better tests and docs.




&nbsp;


License
-------
<!--#echo json="package.json" key=".license" -->
ISC
<!--/#echo -->
