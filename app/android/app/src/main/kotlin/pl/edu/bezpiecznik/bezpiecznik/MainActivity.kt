package pl.edu.bezpiecznik.bezpiecznik

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    // One page at a time, off the UI thread: PdfRenderer allows a single open
    // page and rendering an A4 page takes tens of milliseconds.
    private val pdfExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Offline PDF pages for the guides reader (lib/poradniki), drawn with
        // the platform PdfRenderer so the app needs no PDF library.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bezpiecznik/pdf")
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "path is required", null)
                    return@setMethodCallHandler
                }
                pdfExecutor.execute {
                    try {
                        val value: Any = when (call.method) {
                            "pageSizes" -> pageSizes(path)
                            "renderPage" -> renderPage(
                                path,
                                call.argument<Int>("index") ?: 0,
                                call.argument<Int>("width") ?: 1080,
                            )
                            else -> {
                                mainHandler.post { result.notImplemented() }
                                return@execute
                            }
                        }
                        mainHandler.post { result.success(value) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("pdf", e.message, null) }
                    }
                }
            }
    }

    private fun <T> withPdf(path: String, block: (PdfRenderer) -> T): T {
        val fd = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = PdfRenderer(fd)
        try {
            return block(renderer)
        } finally {
            renderer.close()
            fd.close()
        }
    }

    /** Width and height of every page in points: [w0, h0, w1, h1, ...]. */
    private fun pageSizes(path: String): List<Int> = withPdf(path) { pdf ->
        val sizes = ArrayList<Int>(pdf.pageCount * 2)
        for (i in 0 until pdf.pageCount) {
            pdf.openPage(i).use { page ->
                sizes.add(page.width)
                sizes.add(page.height)
            }
        }
        sizes
    }

    /** Page [index] as a JPEG, [width] pixels wide, on a white background. */
    private fun renderPage(path: String, index: Int, width: Int): ByteArray = withPdf(path) { pdf ->
        pdf.openPage(index).use { page ->
            val height = (width.toLong() * page.height / page.width).toInt()
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            try {
                bitmap.eraseColor(Color.WHITE)
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                val out = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 88, out)
                out.toByteArray()
            } finally {
                bitmap.recycle()
            }
        }
    }

    override fun onDestroy() {
        pdfExecutor.shutdown()
        super.onDestroy()
    }
}
