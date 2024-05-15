
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

* MS SAPI v11: `tts-cli/serverTtsCli.cs` from
  https://github.com/mk-pmb/msspeechsdk_v011_wine_howto/
* Logox 4: `tts-cli/logox4_cli_simple.cs` from
  https://github.com/mk-pmb/webspeech-util-pmb/




Research notes
--------------

### Offline speech recognition

* [Wikipedia has a list.
  ](https://en.wikipedia.org/wiki/List_of_speech_recognition_software)
* [CMU Sphinx](https://cmusphinx.github.io/wiki/): Mostly BSD-licensed.
  CMU = Carnegie Mellon University. Family of SR tools and libraries.
  * __PocketSphinx:__ Lightweight. Easy setup. Designed for small vocabularies.
    Supports custom language models.
* [Kaldi](http://kaldi-asr.org/): Apache 2.0 License. "Powerful" SR toolkit.
  "State-of-the-art" performance and flexibility. Somewhat complex setup.
  Supports custom acoustic and language models.



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
