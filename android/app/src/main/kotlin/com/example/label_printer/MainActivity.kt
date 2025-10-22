package com.itsng.label_printer

import android.content.Intent
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.documentfile.provider.DocumentFile

class MainActivity : FlutterActivity() {
	private val CHANNEL = "com.itsng.label_printer/files"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"getPublicDocumentsDir" -> {
					val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
					result.success(dir?.absolutePath)
				}
				"writeFileToSaf" -> {
					val uriString = call.argument<String>("directoryUri")
					val relativePath = call.argument<String>("relativePath") ?: ""
					val fileName = call.argument<String>("fileName")
					val bytes = call.argument<ByteArray>("bytes")
					if (uriString.isNullOrBlank() || fileName.isNullOrBlank() || bytes == null) {
						result.error("bad_args", "Invalid SAF write arguments", null)
						return@setMethodCallHandler
					}
					try {
						writeFileToSaf(uriString, relativePath, fileName, bytes)
						result.success(null)
					} catch (e: Exception) {
						result.error("saf_write_failed", e.message, null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun writeFileToSaf(directoryUri: String, relativePath: String, fileName: String, bytes: ByteArray) {
		val resolver = applicationContext.contentResolver
		val treeUri = Uri.parse(directoryUri)
		var directory = DocumentFile.fromTreeUri(applicationContext, treeUri)
			?: throw IllegalArgumentException("Invalid SAF directory URI")
		try {
			resolver.takePersistableUriPermission(
				treeUri,
				Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
			)
		} catch (_: SecurityException) {
			// 이미 권한을 가지고 있으면 예외가 발생할 수 있음. 무시.
		}

		relativePath
			.split('/')
			.map { it.trim() }
			.filter { it.isNotEmpty() }
			.forEach { segment ->
				var next = directory.findFile(segment)
				if (next == null || !next.isDirectory) {
					next?.delete()
					next = directory.createDirectory(segment)
				}
				directory = next ?: throw IllegalStateException("Failed to create SAF directory segment: $segment")
			}

		directory.findFile(fileName)?.delete()
		val target = directory.createFile("application/octet-stream", fileName)
			?: throw IllegalStateException("Failed to create SAF file")

		resolver.openOutputStream(target.uri, "wt")?.use { stream ->
			stream.write(bytes)
			stream.flush()
		} ?: throw IllegalStateException("Failed to open SAF output stream")
	}
}
