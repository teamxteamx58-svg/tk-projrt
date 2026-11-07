package com.bassarizik.app;

import android.Manifest;
import android.content.ContentUris;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.MediaStore;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;

/**
 * Coquille Android de BASSARI-ZIK : affiche le site dans une WebView et
 * fournit au site (objet JavaScript « BzNative ») l'accès aux fichiers audio
 * du téléphone, après l'accord de l'utilisateur.
 */
public class MainActivity extends AppCompatActivity {

    private static final String SITE = "https://teamxteamx58-svg.github.io/tk-projrt/";
    private static final int REQ_AUDIO = 42;

    private WebView web;

    private String audioPermission() {
        return Build.VERSION.SDK_INT >= 33
                ? Manifest.permission.READ_MEDIA_AUDIO
                : Manifest.permission.READ_EXTERNAL_STORAGE;
    }

    private boolean hasAudioPermission() {
        return ContextCompat.checkSelfPermission(this, audioPermission()) == PackageManager.PERMISSION_GRANTED;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        web = new WebView(this);
        setContentView(web);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);

        web.setWebViewClient(new WebViewClient());
        web.setWebChromeClient(new WebChromeClient());
        web.addJavascriptInterface(new Bridge(), "BzNative");
        web.loadUrl(SITE);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] results) {
        super.onRequestPermissionsResult(requestCode, permissions, results);
        if (requestCode == REQ_AUDIO) {
            final boolean ok = results.length > 0 && results[0] == PackageManager.PERMISSION_GRANTED;
            web.post(() -> web.evaluateJavascript("window.bzOnPerm && window.bzOnPerm(" + ok + ")", null));
        }
    }

    @Override
    public void onBackPressed() {
        if (web.canGoBack()) web.goBack();
        else super.onBackPressed();
    }

    /** Méthodes appelables depuis le site : BzNative.xxx(). */
    class Bridge {

        @JavascriptInterface
        public boolean hasPermission() {
            return hasAudioPermission();
        }

        @JavascriptInterface
        public void requestPermission() {
            runOnUiThread(() -> ActivityCompat.requestPermissions(
                    MainActivity.this, new String[]{audioPermission()}, REQ_AUDIO));
        }

        /** Liste des morceaux du téléphone, au format JSON. */
        @JavascriptInterface
        public String listAudio() {
            JSONArray arr = new JSONArray();
            if (!hasAudioPermission()) return arr.toString();

            String[] proj = {
                    MediaStore.Audio.Media._ID,
                    MediaStore.Audio.Media.TITLE,
                    MediaStore.Audio.Media.ARTIST,
                    MediaStore.Audio.Media.DURATION
            };
            String sel = MediaStore.Audio.Media.IS_MUSIC + " != 0";
            try (Cursor c = getContentResolver().query(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, proj, sel, null,
                    MediaStore.Audio.Media.TITLE + " ASC")) {
                if (c != null) {
                    while (c.moveToNext()) {
                        try {
                            JSONObject o = new JSONObject();
                            o.put("id", c.getLong(0));
                            o.put("title", c.getString(1));
                            o.put("artist", c.getString(2));
                            o.put("duration", c.getLong(3));
                            arr.put(o);
                        } catch (Exception ignored) { }
                    }
                }
            } catch (Exception ignored) { }
            return arr.toString();
        }

        /** Contenu d'un morceau encodé en base64 (le site en fait un lecteur). */
        @JavascriptInterface
        public String readAudio(long id) {
            if (!hasAudioPermission()) return "";
            try {
                Uri u = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id);
                InputStream in = getContentResolver().openInputStream(u);
                if (in == null) return "";
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                byte[] buf = new byte[65536];
                int n;
                while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
                in.close();
                return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP);
            } catch (Exception e) {
                return "";
            }
        }
    }
}
