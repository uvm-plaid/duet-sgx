package duetsgxmicropal;

import android.os.Bundle;
import android.pal.item.Item;
import android.pal.item.ListItem;
import android.pal.item.calendar.CalendarEventItem;
import android.pal.item.communication.ContactItem;
import android.pal.item.location.LocationItem;
import android.privatedata.DataRequest;
import android.privatedata.MicroPALProviderService;
import android.util.Base64;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONTokener;

import java.io.UnsupportedEncodingException;
import java.nio.charset.Charset;
import java.security.InvalidKeyException;
import java.security.KeyFactory;
import java.security.NoSuchAlgorithmException;
import java.security.PublicKey;
import java.security.Signature;
import java.security.SignatureException;
import java.security.spec.X509EncodedKeySpec;
import java.util.ArrayList;
import java.util.List;

import javax.crypto.Cipher;

public class DuetSGXMicroPAL extends MicroPALProviderService {
    DataRequest.DataType dataType;
    private static final String TAG = "DuetSGXMicroPal";

    public DuetSGXMicroPAL() {
        super(DataRequest.DataType.ANY);
    }

    /**
     * Decode an RSA public key in a string into a PublicKey object.
     * @param keystr A string containing an RSA public key
     * @return The PublicKey object containing the key
     * @throws Exception
     */
    private PublicKey decodePublicKey(String keystr) throws Exception {
        Log.w(TAG, "Decoding public key from string: " + keystr);

        // Remove the first and last lines
        String pubKeyPEM = new String(keystr.getBytes(), "UTF-8");
        pubKeyPEM = pubKeyPEM.replaceAll("-----BEGIN PUBLIC KEY-----", "");
        pubKeyPEM = pubKeyPEM.replaceAll("-----END PUBLIC KEY-----", "");
        pubKeyPEM = pubKeyPEM.replace("\\n", "");

        // Base64 decode the data
        byte [] encoded = Base64.decode(pubKeyPEM, Base64.DEFAULT);
        X509EncodedKeySpec keySpec = new X509EncodedKeySpec(encoded);
        KeyFactory kf = KeyFactory.getInstance("RSA");
        PublicKey pubkey = kf.generatePublic(keySpec);

        Log.w(TAG, "Decoded public key: " + pubkey);

        return pubkey;
    }

    /**
     * Download a signed parameter value from the DuetSGX server and verify the signature.
     * @param serverAddress The address of the DuetSGX server
     * @param route The route to the desired parameter
     * @param pubKey The public key in use by the DuetSGX server
     * @return The value of the requested parameter (as a double) if the signature verifies
     * @throws Exception If the signature fails to verify
     */
    private double getAndVerifyParam(String serverAddress, String route, PublicKey pubKey) throws Exception {
        Log.w(TAG, "Requesting parameter " + route + " at address " + serverAddress + "/" + route);

        String result = DuetSGXHTTPRequest.sendRequest(serverAddress + "/" + route,
                "GET", null, Bundle.EMPTY);

        Log.w(TAG, "Parameter result for " + route + ": " + result);

        try {
            JSONObject root = new JSONObject(new JSONTokener(result));
            String r1 = root.getString(route);
            String r = r1.replace("\\n", "").replace("\"", "");

            Log.w(TAG, "Parsed parameter value to: " + Double.parseDouble(r));

            String sig = root.getString("signature");

            Signature sign = Signature.getInstance("SHA1withRSA/PSS");
            sign.initVerify(pubKey);
            String signature = new String(sig.getBytes(), "UTF-8");
            byte [] decoded = Base64.decode(signature, Base64.DEFAULT);
            sign.update(r1.getBytes(Charset.forName("UTF-8")));
            boolean verified = sign.verify(decoded);

            Log.w(TAG, "Signature verification result: " + verified);

            if (!verified)
                throw new RuntimeException("Failed to verify parameter signature! " + result);

            return Double.parseDouble(r);
        } catch (JSONException | NoSuchAlgorithmException | InvalidKeyException | UnsupportedEncodingException | SignatureException e) {
            e.printStackTrace();
            throw new RuntimeException("Failed");
        }
    }

    /**
     * Attest the DuetSGX server. Requests the quote from the server, then sends it to Intel's
     * SGX verification service. Throws an exception if the attestation fails.
     * @param serverAddress The address of the DuetSGX server
     * @return The attestation result (true = attestation successful)
     */
    private boolean attest(String serverAddress) {
        Log.w(TAG, "Starting attestation");

        String quote = DuetSGXHTTPRequest.sendRequest(serverAddress + "/attest",
                "GET", null, Bundle.EMPTY);

        Log.w(TAG, "Got attestation quote: " + quote);

        if (quote.equals("Attestation quote not available")) {
            Log.w(TAG, "Got attestation result: " + quote);
            return true;
        } else {
            // Send the quote to the Intel attestation service
            Bundle headers = Bundle.EMPTY;
            headers.putString("Ocp-Apim-Subscription-Key", "d16d302575a74bfca8f4994339d160f2");
            String intelURL = "https://api.trustedservices.intel.com/sgx/dev/attestation/v3/report";

            // Verify the attestation response
            // "sendRequest" throws an exception if quote verification fails, short-circuiting the operation
            String attestationResponse = DuetSGXHTTPRequest.sendRequest(intelURL, "POST", quote, headers);
            Log.w(TAG, "Got attestation response: " + attestationResponse);

            return true;
        }
    }


    /**
     * Retrieve the public key of the DuetSGX server
     * @param serverAddress The address of the DuetSGX server
     * @return The public key, as a PublicKey object
     * @throws Exception
     */
    private PublicKey getPubKey(String serverAddress) throws Exception {
        Log.w(TAG, "Starting to get public key");

        String pubKeyPEM = DuetSGXHTTPRequest.sendRequest(serverAddress + "/pubkeypem",
                "GET", null, Bundle.EMPTY);

        Log.w(TAG, "Got public key: " + pubKeyPEM);

        return decodePublicKey(pubKeyPEM);
    }

    /**
     * The onReceive method for the DuetSGX microPAL. Performs X steps:
     * 1. Attest the DuetSGX server
     * 2. Obtain the DuetSGX server's public key
     * 3. Obtain the current epsilon and delta values from the DuetSGX server and verify that
     *    they are smaller than the maximum epsilon and delta specified in the module's parameters
     * 4. Transform the item into a string for insertion into the DuetSGX database
     * 5. Encrypt the transformed item using the DuetSGX server's public key
     * 6. Send the encrypted item to the DuetSGX server
     * @param item The item to insert into the DuetSGX server
     * @param bundle The parameters specified by the invoking application
     * @return If successful, a bundle specifying success; otherwise, a bundle specifying an
     * error message.
     */
    @Override
    public Bundle onReceive(Item item, Bundle bundle) {
        Log.w(TAG, "Entering 'onReceive' method of DuetSGX microPAL");

        String serverAddress = bundle.getString("server_address");

        Double maxEpsilon = bundle.getDouble("max_epsilon");
        Double maxDelta = bundle.getDouble("max_delta");

        Log.w(TAG, "DuetSGX server address: " + serverAddress);
        Log.w(TAG, "Item to be inserted is: " + item.toString());
        Log.w(TAG, "App-specified parameters: " + bundle.toString());

        // Step 1: attest the DuetSGX server
        boolean attestationResult = attest(serverAddress);
        if (!attestationResult) {
            Log.w(TAG, "Attestation failed!");
            return null;
        }


        Log.w(TAG, "Finished attestation");

        // Step 2: obtain the public key
        PublicKey pubKey;
        try {
            pubKey = getPubKey(serverAddress);
        } catch (Exception e) {
            Log.w(TAG, "Error in getting public key: " + e.toString());
            e.printStackTrace();

            return null;
        }

        // Step 3: check epsilon and delta values
        // Check that the epsilon and delta satisfy the user's requirements
        double epsilonVal = 0;
        double deltaVal = 0;

        try {
            epsilonVal = getAndVerifyParam(serverAddress, "epsilon", pubKey);
            deltaVal = getAndVerifyParam(serverAddress, "delta", pubKey);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }

        if (epsilonVal > maxEpsilon || deltaVal > maxDelta)
            return null;

        Log.w(TAG, "Got epsilon/delta: (" + Double.toString(epsilonVal) + ", " +
                Double.toString(deltaVal) + ")");

        // Step 4: transform the <item> into a string for insertion
        List<String> transformedItem = null;

        if (item instanceof LocationItem) {
            transformedItem = new ArrayList<>();
            transformedItem.add(LocationTransformer.transform((LocationItem) item));
        } else if (item instanceof ListItem) {
            ListItem<Item> li = (ListItem<Item>)item;
            ArrayList<Item> storedItems = li.getStoredItems();

            if (storedItems.size() == 0) {
                Log.w(TAG, "Nothing to transform in the list of items!");
                return null;
            } else {
                Item firstItem = storedItems.get(0);
                if (firstItem instanceof CalendarEventItem) {
                    transformedItem = new ArrayList<>();
                    transformedItem.add(AvailabilityBitmapTransformer.transform(
                                        (ListItem<CalendarEventItem>) item, bundle));
                } else if (firstItem instanceof ContactItem) {
                    transformedItem = ContactTransformer.transform((ListItem<ContactItem>) item);
                } else {
                    Log.w(TAG, "Unimplemented");
                    return null;
                }
            }
        } else {
            Log.w(TAG, "Failed to transform the <item>: " + item.toString());
            return null;
        }



        try {
            // Step 5: encrypt the transformed string with the public key
            Log.w(TAG, "Encrypting the data: " + transformedItem);

            for (String s : transformedItem) {
                Cipher cipher = Cipher.getInstance("RSA/ECB/OAEPPadding");
                cipher.init(Cipher.ENCRYPT_MODE, pubKey);
                byte[] encryptedBytes = cipher.doFinal(s.getBytes());
                String encryptedString = Base64.encodeToString(encryptedBytes, Base64.DEFAULT);
                encryptedString = encryptedString.replace("\n", "");
                Log.w(TAG, "Encrypted result is: " + encryptedString);

                // Step 5: insert the encrypted string into the database
                JSONObject json = new JSONObject();
                json.put("value", encryptedString);

                // Step 5: send the encrypted value to the DuetSGX server
                DuetSGXHTTPRequest.sendRequest(serverAddress + "/insert",
                        "POST", json.toString(), Bundle.EMPTY);
                Log.w(TAG, "Successfully sent insertion");
            }


        } catch (Exception e) {
            e.printStackTrace();
        }

        Bundle returnVal = new Bundle();
        returnVal.putString("status", "success");
        return returnVal;
    }

    @Override
    public String getDescription() {
        return "DuetSGX microPAL module";
    }
}
