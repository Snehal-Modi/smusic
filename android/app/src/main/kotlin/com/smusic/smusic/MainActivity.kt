package com.smusic.smusic

import android.content.ContentUris
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : AudioServiceActivity() {
    private val channelName = "smusic/media"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "querySongs" -> {
                    Thread {
                        val songs = try { querySongs() } catch (e: Exception) { ArrayList<Map<String, Any?>>() }
                        runOnUiThread { result.success(songs) }
                    }.start()
                }
                "getArt" -> {
                    val id = (call.argument<Number>("id") ?: 0).toLong()
                    val albumId = (call.argument<Number>("albumId") ?: 0).toLong()
                    val size = call.argument<Int>("size") ?: 300
                    Thread {
                        val bytes = getArt(id, albumId, size)
                        runOnUiThread { result.success(bytes) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun querySongs(): List<Map<String, Any?>> {
        val list = ArrayList<Map<String, Any?>>()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.YEAR,
            MediaStore.Audio.Media.SIZE
        )
        val selection = MediaStore.Audio.Media.IS_MUSIC + " != 0 AND " + MediaStore.Audio.Media.DURATION + " >= 20000"
        val sort = MediaStore.Audio.Media.TITLE + " COLLATE NOCASE ASC"
        contentResolver.query(collection, projection, selection, null, sort)?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumIdCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val durCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val dataCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val addedCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val trackCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
            val yearCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)
            val sizeCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            while (c.moveToNext()) {
                val id = c.getLong(idCol)
                val m = HashMap<String, Any?>()
                m["id"] = id
                m["title"] = c.getString(titleCol) ?: ""
                m["artist"] = c.getString(artistCol) ?: ""
                m["album"] = c.getString(albumCol) ?: ""
                m["albumId"] = c.getLong(albumIdCol)
                m["duration"] = c.getLong(durCol)
                m["path"] = c.getString(dataCol) ?: ""
                m["dateAdded"] = c.getLong(addedCol)
                m["track"] = c.getInt(trackCol)
                m["year"] = c.getInt(yearCol)
                m["size"] = c.getLong(sizeCol)
                m["uri"] = ContentUris.withAppendedId(collection, id).toString()
                list.add(m)
            }
        }
        return list
    }

    private fun getArt(id: Long, albumId: Long, size: Int): ByteArray? {
        return try {
            var bmp: Bitmap? = null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    val songUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                    bmp = contentResolver.loadThumbnail(songUri, Size(size, size), null)
                } catch (e: Exception) {
                    bmp = null
                }
            }
            if (bmp == null) {
                val artUri = ContentUris.withAppendedId(Uri.parse("content://media/external/audio/albumart"), albumId)
                contentResolver.openInputStream(artUri)?.use { input ->
                    val raw = BitmapFactory.decodeStream(input)
                    if (raw != null) {
                        bmp = if (raw.width > size) {
                            Bitmap.createScaledBitmap(raw, size, size * raw.height / raw.width, true)
                        } else {
                            raw
                        }
                    }
                }
            }
            val b = bmp ?: return null
            val out = ByteArrayOutputStream()
            b.compress(Bitmap.CompressFormat.JPEG, 88, out)
            out.toByteArray()
        } catch (e: Exception) {
            null
        }
    }
}
