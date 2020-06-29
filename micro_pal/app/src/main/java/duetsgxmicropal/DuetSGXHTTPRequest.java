package duetsgxmicropal;

import android.os.Bundle;
import android.util.Log;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

class DuetSGXHTTPRequest {
    public static String TAG = "DuetSGXHTTPRequest";

    public static String sendRequest(String urlAddress, String requestMethod, String data, Bundle headers) {
        try {
            Log.i(TAG, "Making HTTP Request: " + urlAddress + "; " + requestMethod + "; " + data);

            // Set up the connection
            URL url = new URL(urlAddress);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod(requestMethod);
            conn.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
            conn.setRequestProperty("Accept","application/json");

            for (String k : headers.keySet()) {
                conn.setRequestProperty(k, headers.getString(k));
            }

            conn.setDoInput(true);

            conn.setConnectTimeout(5000);
            conn.setReadTimeout(5000);

            // Send the request
            if (data == null) {
                conn.setRequestProperty("Content-length", "0");
            } else {
                conn.setDoOutput(true);

                DataOutputStream os = new DataOutputStream(conn.getOutputStream());
                os.writeBytes(data);

                os.flush();
                os.close();
            }

            Log.i(TAG, String.valueOf(conn.getResponseCode()));
            Log.i(TAG , conn.getResponseMessage());

            // Throw an exception if unsuccessful
            if (conn.getResponseCode() != 200)
                throw new RuntimeException("Failure: response code was " + conn.getResponseCode());

            // Read in the response
            try(BufferedReader br = new BufferedReader(
                    new InputStreamReader(conn.getInputStream(), "utf-8"))) {
                StringBuilder response = new StringBuilder();
                String responseLine = null;
                while ((responseLine = br.readLine()) != null) {
                    response.append(responseLine.trim());
                }
                String responseString = response.toString();

                //System.out.println(responseString);
                conn.disconnect();
                return responseString;
            } finally {
                conn.disconnect();
            }

        } catch (Exception e) {
            Log.i(TAG, "Problem sending HTTP Request: " + e.toString());
            Log.i(TAG, "Message: " + e.getMessage());

            e.printStackTrace();
            throw new RuntimeException("Failure");
        }

    }
}
