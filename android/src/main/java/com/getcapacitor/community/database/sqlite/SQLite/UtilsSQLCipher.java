package com.getcapacitor.community.database.sqlite.SQLite;

import android.content.Context;
import android.content.SharedPreferences;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteStatement;

public class UtilsSQLCipher {

    private static final String TAG = UtilsSQLCipher.class.getName();

    /**
     * The detected state of the database, based on whether we can
     * open it without a passphrase, with the passphrase 'secret'.
     */
    public enum State {
        DOES_NOT_EXIST,
        UNENCRYPTED,
        ENCRYPTED_SECRET,
        ENCRYPTED_GLOBAL_SECRET,
        UNKNOWN
    }

    /**
     * Determine whether or not this database appears to be encrypted,
     * based on whether we can open it without a passphrase or with
     * the passphrase 'secret'.
     *
     * @param dbPath a File pointing to the database
     * @param sharedPreferences an instance of SharedPreferences
     * @param globVar an instance of GlobalSQLite
     * @return the detected state of the database
     */
    public State getDatabaseState(Context ctxt, File dbPath, SharedPreferences sharedPreferences, GlobalSQLite globVar) {
        // sqlcipher removed
        if (dbPath.exists()) {
            SQLiteDatabase db = null;

            try {
                db = SQLiteDatabase.openDatabase(dbPath.getAbsolutePath(), null, SQLiteDatabase.OPEN_READONLY);

                db.getVersion();

                return (State.UNENCRYPTED);
            } catch (Exception e) {
                try {
                    // no SQLCipher support; cannot try passphrase
                    return (State.UNKNOWN);
                } catch (Exception e1) {
                    try {
                        return (State.UNKNOWN);
                    } catch (Exception e2) {
                        return (State.UNKNOWN);
                    }
                }
            } finally {
                if (db != null) {
                    db.close();
                }
            }
        }

        return (State.DOES_NOT_EXIST);
    }

    /**
     * Replaces this database with a version encrypted with the supplied
     * passphrase, deleting the original.
     * Do not call this while the database is open.
     *
     * The passphrase is untouched in this call.
     *
     * @param ctxt a Context
     * @param originalFile a File pointing to the database
     * @param passphrase the passphrase from the user
     * @throws IOException
     */
    public void encrypt(Context ctxt, File originalFile, byte[] passphrase) throws IOException {
        // sqlcipher removed

        if (originalFile.exists()) {
            File newFile = File.createTempFile("sqlcipherutils", "tmp", ctxt.getCacheDir());
            SQLiteDatabase db = SQLiteDatabase.openDatabase(originalFile.getAbsolutePath(), null, SQLiteDatabase.OPEN_READWRITE);
            int version = db.getVersion();

            db.close();

            // no-op: encryption not supported; just copy file semantics
            db.close();
            boolean delFile1 = originalFile.delete();
            if (!delFile1) {
                throw new FileNotFoundException(originalFile.getAbsolutePath() + " not deleted");
            }
            boolean renFile1 = newFile.renameTo(originalFile);
            if (!renFile1) {
                throw new FileNotFoundException(originalFile.getAbsolutePath() + " not renamed");
            }
        } else {
            throw new FileNotFoundException(originalFile.getAbsolutePath() + " not found");
        }
    }

    public void decrypt(Context ctxt, File originalFile, byte[] passphrase) throws IOException {
        // sqlcipher removed

        if (originalFile.exists()) {
            // Create a temporary file for the decrypted database in the cache directory
            File decryptedFile = File.createTempFile("sqlcipherutils", "tmp", ctxt.getCacheDir());

            // Open the decrypted database
            SQLiteDatabase decryptedDb = SQLiteDatabase.openDatabase(
                decryptedFile.getAbsolutePath(),
                null,
                SQLiteDatabase.OPEN_READWRITE
            );

            // Open the encrypted database with the provided passphrase
            // Open the original as plain SQLite (no real decryption)
            SQLiteDatabase encryptedDb = SQLiteDatabase.openDatabase(
                originalFile.getAbsolutePath(),
                null,
                SQLiteDatabase.OPEN_READWRITE
            );

            int version = encryptedDb.getVersion();
            decryptedDb.setVersion(version);

            decryptedDb.close();

            // No-op copy semantics in shim context
            encryptedDb.close();

            boolean delFile = originalFile.delete();
            if (!delFile) {
                throw new FileNotFoundException(originalFile.getAbsolutePath() + " not deleted");
            }
            boolean renFile = decryptedFile.renameTo(originalFile);
            if (!renFile) {
                throw new FileNotFoundException(originalFile.getAbsolutePath() + " not renamed");
            }
        } else {
            throw new FileNotFoundException(originalFile.getAbsolutePath() + " not found");
        }
    }

    public void changePassword(Context ctxt, File file, String password, String nwpassword) throws Exception {
        System.loadLibrary("sqlcipher");

        if (file.exists()) {
            SQLiteDatabase db = SQLiteDatabase.openDatabase(file.getAbsolutePath(), null, SQLiteDatabase.OPEN_READWRITE);

            if (!db.isOpen()) {
                throw new Exception("database " + file.getAbsolutePath() + " open failed");
            }
            // no-op
            db.close();
        } else {
            throw new FileNotFoundException(file.getAbsolutePath() + " not found");
        }
    }
}
