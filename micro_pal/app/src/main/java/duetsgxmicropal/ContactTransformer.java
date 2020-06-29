package duetsgxmicropal;

import android.pal.item.ListItem;
import android.pal.item.communication.ContactItem;

import java.util.ArrayList;
import java.util.List;

class ContactTransformer {
    public static List<String> transform(ListItem<ContactItem> item) {
        List returnVal = new ArrayList<String>();
        for (ContactItem i : item.getStoredItems()) {
            returnVal.add(i.getId() + "," + i.getName());
        }

        return returnVal;
    }
}
