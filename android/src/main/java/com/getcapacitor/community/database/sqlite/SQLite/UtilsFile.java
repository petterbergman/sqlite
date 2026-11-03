package com.getcapacitor.community.database.sqlite.SQLite;

import android.content.Context;
import java.io.File;

public class UtilsFile {

    public Boolean isFileExists(Context context, String dbName) {
        File file = context.getDatabasePath(dbName);
        return file.exists();
    }

    public Boolean deleteFile(Context context, String dbName) {
        File file = context.getDatabasePath(dbName);
        return file.delete();
    }
}
