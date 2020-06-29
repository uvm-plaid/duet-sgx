# Description

DuetSGX provides a HTTP API for clients to contribute data for
differentially private analysis. Software running on a trusted client
may use this HTTP API to contribute data to a DuetSGX server,
following the process outlined in the overview.


## Using the Web Interface

A simple web interface for inserting data and running queries is
provided by the DuetSGX server. After setting up the server, navigate
to `http://localhost:5000/` to use this interface.

The web interface displays the DuetSGX server's public key and
includes a text box for inserting new data rows. The web interface
includes Javascript code to encrypt the text from the text box using
the server's public key and submit it to the DuetSGX server (i.e. the
encryption step occurs on the client side, using a Javascript
implementation, and does not require trusting the server to perform
the encryption).

Note that the web interface does **not** perform remote attestation.


## Using the PEAndroid μPAL Module

We have also developed a μPAL module for use with [Privacy
Enhancements for Android (PEAndroid)](https://android-privacy.org/),
to allow Android applications to easily contribute data to a DuetSGX
server without requiring trust in the Android application itself. For
example, an Android application can send the phone's location to a
DuetSGX server without the application requiring location
privileges—in this scenario, only the PEAndroid operating system and
DuetSGX μPAL module are trusted—the application itself will not have
access to the user's location, even if it is malicious.

The μPAL module is available (source code and APK) in the `micro_pal`
subdirectory of the DuetSGX repository. Installing the APK will make
the μPAL module available to Android applications.

In your Android application, you can use code like the following to
call the DuetSGX μPAL and send the user's location to the DuetSGX
server:

```java
// Set up the private data manager, PAL name, purpose, and data type
PrivateDataManager pdm = PrivateDataManager.getInstance();
String palName = "duetsgxmicropal.DuetSGXMicroPAL";
DataRequest.DataType dt = DataRequest.DataType.LOCATION;
Bundle locationParams = new DataRequest.LocationParamsBuilder()
        .setUpdateMode(DataRequest.LocationParamsBuilder.MODE_LAST_LOCATION)
        .setTimeoutMillis(60000)
        .build();

DataRequest.Purpose purpose = DataRequest.Purpose.ADS("Testing"); // set the purpose for the request

Bundle palParams = new Bundle();
palParams.putString("server_address", "http://10.0.2.2:5000");  // set the DuetSGX server address
palParams.putDouble("max_epsilon", 1.0);                        // set the maximum allowed epsilon value
palParams.putDouble("max_delta", 0.00001);                      // set the maximum allowed delta value

// Specify the callback
ResultReceiver callback = new ResultReceiver(null) {
    @Override
    protected void onReceiveResult(int resultCode, Bundle resultData) {
        if(resultCode == PrivateDataManager.RESULT_SUCCESS) {
            Log.d(TAG, "Received callback");
        }
    }
};

// Make the request
DataRequest request = new DataRequest(this, dt, locationParams, palName, palParams, purpose, callback);
pdm.requestData(request);
```

For more information on using PEAndroid μPAL modules, see the
[PEAndroid project](https://android-privacy.org/).
