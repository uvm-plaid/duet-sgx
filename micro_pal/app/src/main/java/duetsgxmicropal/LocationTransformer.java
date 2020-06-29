package duetsgxmicropal;

import android.pal.item.location.LocationItem;
import android.util.Log;

class LocationTransformer {

    public static String transform(LocationItem locationItem) {
        double latitude = locationItem.getLatitude();
        double longitude = locationItem.getLongitude();

        Log.w("DuetSGXMicroPal", "lat/lng is: " + Double.toString(latitude) + "," + Double.toString(longitude));


        return latitude + "," + longitude;
    }
}
