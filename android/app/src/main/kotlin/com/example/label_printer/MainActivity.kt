package com.itsng.label_printer

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.DocumentsContract
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import androidx.documentfile.provider.DocumentFile
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val cn = "DbServerConnectInfoHelper";
        private const val PREFS = "storage_prefs"
        private const val KEY_TREE_URI = "documents_tree_uri"
        private const val DB_FILE_NAME = "labelmanager_server_connect_info.db"
        private const val DB_ASSET_FULL_PATH = "flutter_assets/assets/data"
        private const val FOLDER_DATA = "data"
    }

    private var pendingCont: CancellableContinuation<String?>? = null

    private fun deleteUriSafely(uri: Uri): Boolean {
        val fn = "deleteUriSafely";
        return try {
            Log.d(cn, "$fn: Deleting URI $uri");
            // 문서 제공자(DocumentProvider) 기반 URI인 경우 우선 시도
            if (DocumentsContract.isDocumentUri(this, uri)) {
                try {
                    DocumentsContract.deleteDocument(contentResolver, uri)
                    return true
                } catch (_: Exception) {
                    // 대안: DocumentFile
                    val ok = DocumentFile.fromSingleUri(this, uri)?.delete() == true
                    if (ok) return true
                }
            }
            // 그 외(또는 위에서 실패) 일반 ContentResolver 삭제 시도
            contentResolver.delete(uri, null, null) > 0
        } catch (_: Exception) {
            false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "${applicationContext.packageName}/storage"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareDocumentsAndGetPath" -> {
                    val fn = "prepareDocumentsAndGetPath";
                    Log.d(cn, "$fn: prepareDocumentsAndGetPath");
                    if (pendingCont != null) {
                        result.error("BUSY", "작업이 이미 진행 중입니다.", null)
                        return@setMethodCallHandler
                    }
                    // Dart로부터 isInternalDbExists 인자 받기
                    val isInternalDbExists = call.argument<Boolean>("isInternalDbExists") ?: false
                    lifecycleScope.launch {
                        try {
                            val path = maybePrepareDocumentsAndGetPath(isInternalDbExists)
                            result.success(path)
                        } catch (e: Throwable) {
                            result.error("ERROR", e.message ?: "unknown", null)
                        }
                    }
                }
                "readContentUri" -> {
                    val fn = "readContentUri";
                    Log.d(cn, "$fn: readContentUri");
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("ARG_ERROR", "uri가 필요합니다.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = Uri.parse(uriString)
                        Log.d(cn, "$fn: Reading URI $uri");
                        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                        if (bytes == null) {
                            Log.d(cn, "$fn: Failed to open stream");
                            result.error("READ_ERROR", "스트림을 열 수 없습니다.", null)
                            return@setMethodCallHandler
                        }
                        Log.d(cn, "$fn: Deleting URI $uri");
                        deleteUriSafely(uri)
                        result.success(bytes)
                    } catch (e: Throwable) {
                        result.error("READ_ERROR", "URI를 읽는 중 오류 발생: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private val openDocumentsTree = registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
        val cont = pendingCont ?: return@registerForActivityResult
        if (uri == null) {
            cont.resume(null)
            pendingCont = null
            return@registerForActivityResult
        }
        contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        saveTreeUri(uri)
        lifecycleScope.launch {
            // 최초 권한 획득 시에는 항상 파일을 복사하도록 isInternalDbExists를 false로 전달
            val path = prepareUnderSAF(uri, false)
            cont.resume(path)
            pendingCont = null
        }
    }

    private val requestLegacyPermissions = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
        val cont = pendingCont ?: return@registerForActivityResult
        val granted = result.values.all { it }
        lifecycleScope.launch {
            // 최초 권한 획득 시에는 항상 파일을 복사하도록 isInternalDbExists를 false로 전달
            val path = if (granted) prepareUnderLegacy(false) else null
            cont.resume(path)
            pendingCont = null
        }
    }

    private suspend fun maybePrepareDocumentsAndGetPath(isInternalDbExists: Boolean): String? {
        loadTreeUri()?.let { persisted ->
            if (hasPersistedPermission(persisted)) {
                return prepareUnderSAF(persisted, isInternalDbExists)
            }
            else clearTreeUri()
        }

        return when {
            Build.VERSION.SDK_INT >= 30 -> { // Android 11+
                suspendCancellableCoroutine { cont ->
                    pendingCont = cont
                    openDocumentsTree.launch(initialDocumentsUri())
                    cont.invokeOnCancellation { pendingCont = null }
                }
            }
            else -> { // Android 10 이하
                suspendCancellableCoroutine { cont ->
                    pendingCont = cont
                    requestLegacyPermissions.launch(arrayOf(
                        android.Manifest.permission.READ_EXTERNAL_STORAGE,
                        android.Manifest.permission.WRITE_EXTERNAL_STORAGE))
                    cont.invokeOnCancellation { pendingCont = null }
                }
            }
        }
    }

    private suspend fun prepareUnderSAF(treeUri: Uri, isInternalDbExists: Boolean): String? = withContext(Dispatchers.IO) {
        val fn = "prepareUnderSAF";
        Log.d(cn, "$fn: prepareUnderSAF");
        try {
            val root = DocumentFile.fromTreeUri(this@MainActivity, treeUri) ?: return@withContext null
            val packageDir = findOrCreateDirectory(root, applicationContext.packageName) ?: return@withContext null
            val dataDir = findOrCreateDirectory(packageDir, FOLDER_DATA) ?: return@withContext null
            var dbFile = dataDir.findFile(DB_FILE_NAME)

            // 내장 DB도 없고 Documents에도 없으면 Asset에서 Documents에 복사
            if (!isInternalDbExists && (dbFile == null || !dbFile.exists())) {
                if (dbFile == null) {
                    dbFile = dataDir.createFile("application/octet-stream", DB_FILE_NAME) ?: return@withContext null
                }
                Log.d(cn, "$fn: Copying DB from assets to URI ${dbFile.uri}");
                assets.open("$DB_ASSET_FULL_PATH/$DB_FILE_NAME").use { input ->
                    contentResolver.openOutputStream(dbFile.uri, "w")!!.use { output ->
                        input.copyTo(output)
                    }
                }
            }

            dbFile?.uri.toString()
        }
        catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private suspend fun prepareUnderLegacy(isInternalDbExists: Boolean): String? = withContext(Dispatchers.IO) {
        val fn = "prepareUnderLegacy";
        Log.d(cn, "$fn: prepareUnderLegacy");
        try {
            @Suppress("DEPRECATION")
            val docs = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOCUMENTS)
            val packageDir = File(docs, applicationContext.packageName)
            val dataDir = File(packageDir, FOLDER_DATA)
            if (!dataDir.exists() && !dataDir.mkdirs()) return@withContext null
            val dbFile = File(dataDir, DB_FILE_NAME)

            // 내장 DB도 없고 Documents에도 없으면 Asset에서 Documents에 복사
            if (!isInternalDbExists && !dbFile.exists()) {
                Log.d(cn, "$fn: Copying DB from assets to ${dbFile.absolutePath}");
                assets.open("$DB_ASSET_FULL_PATH/$DB_FILE_NAME").use { input ->
                    FileOutputStream(dbFile).use { output ->
                        input.copyTo(output)
                    }
                }
            }

            dbFile?.absolutePath
        }
        catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun findOrCreateDirectory(parent: DocumentFile, name: String): DocumentFile? {
        return parent.findFile(name)?.takeIf { it.isDirectory } ?: parent.createDirectory(name)
    }

    private fun hasPersistedPermission(uri: Uri): Boolean {
        return contentResolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission && it.isWritePermission }
    }

    private fun saveTreeUri(uri: Uri) {
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_TREE_URI, uri.toString()).apply()
    }

    private fun loadTreeUri(): Uri? {
        return getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_TREE_URI, null)?.let { Uri.parse(it) }
    }

    private fun clearTreeUri() {
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().remove(KEY_TREE_URI).apply()
    }

    private fun initialDocumentsUri(): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val docId = "primary:Documents"
            DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", docId)
        } else {
            null
        }
    }
}
