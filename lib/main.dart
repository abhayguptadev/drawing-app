import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
void main() {
  runApp(const DrawingApp());
}

class DrawingApp extends StatefulWidget {
  const DrawingApp({super.key});

  @override
  State<DrawingApp> createState() => _DrawingAppState();
}

class _DrawingAppState extends State<DrawingApp> {
  bool isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: DrawingPage(
        toggleTheme: () {
          setState(() => isDark = !isDark);
        },
      ),
    );
  }
}

class DrawingPoint {
  Offset offset;
  Paint paint;

  DrawingPoint(this.offset, this.paint);
}

class DrawingPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  const DrawingPage({super.key, required this.toggleTheme});

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  List<List<DrawingPoint>> strokes = [];
  List<List<DrawingPoint>> redoStack = [];

  Color selectedColor = Colors.black;
  double strokeWidth = 4;

  bool isEraser = false;
  String brushType = "normal";

  final GlobalKey repaintKey = GlobalKey();

  void startStroke(Offset pos) {
    Paint paint = Paint()
      ..color = isEraser ? Colors.white : selectedColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (brushType == "glow") {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    }

    strokes.add([DrawingPoint(pos, paint)]);
    redoStack.clear();
  }

  void addPoint(Offset pos) {
    strokes.last.add(DrawingPoint(pos, strokes.last.first.paint));
  }

  void undo() {
    if (strokes.isNotEmpty) {
      redoStack.add(strokes.removeLast());
      setState(() {});
    }
  }

  void redo() {
    if (redoStack.isNotEmpty) {
      strokes.add(redoStack.removeLast());
      setState(() {});
    }
  }

  Future<File> saveImage() async {
    await Future.delayed(const Duration(milliseconds: 50));

    RenderRepaintBoundary boundary =
    repaintKey.currentContext!.findRenderObject()
    as RenderRepaintBoundary;

    ui.Image image = await boundary.toImage(pixelRatio: 3);

    ByteData? byteData =
    await image.toByteData(format: ui.ImageByteFormat.png);

    Uint8List bytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/drawing.png');

    await file.writeAsBytes(bytes);

    return file;
  }

  Future<void> shareImage() async {
    final file = await saveImage();
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> exportPDF() async {
    final file = await saveImage();
    final pdf = pw.Document();

    final image = pw.MemoryImage(await file.readAsBytes());

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(child: pw.Image(image)),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Drawing App"),
        actions: [
          IconButton(onPressed: undo, icon: const Icon(Icons.undo)),
          IconButton(onPressed: redo, icon: const Icon(Icons.redo)),
          IconButton(onPressed: widget.toggleTheme, icon: const Icon(Icons.dark_mode)),
          IconButton(onPressed: shareImage, icon: const Icon(Icons.share)),
          IconButton(onPressed: exportPDF, icon: const Icon(Icons.picture_as_pdf)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              key: repaintKey,
              child: GestureDetector(
                onPanStart: (details) {
                  startStroke(details.localPosition);
                },
                onPanUpdate: (details) {
                  setState(() {
                    addPoint(details.localPosition);
                  });
                },
                child: CustomPaint(
                  painter: DrawingPainter(strokes),
                  size: Size.infinite,
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Row(
              children: [
                colorBtn(Colors.black),
                colorBtn(Colors.red),
                colorBtn(Colors.blue),

                IconButton(
                  icon: Icon(
                    Icons.cleaning_services,
                    color: isEraser ? Colors.blue : Colors.black,
                  ),
                  onPressed: () {
                    setState(() => isEraser = !isEraser);
                  },
                ),

                DropdownButton(
                  value: brushType,
                  items: const [
                    DropdownMenuItem(value: "normal", child: Text("Normal")),
                    DropdownMenuItem(value: "glow", child: Text("Glow")),
                  ],
                  onChanged: (val) {
                    setState(() => brushType = val!);
                  },
                ),

                Expanded(
                  child: Slider(
                    value: strokeWidth,
                    min: 1,
                    max: 10,
                    onChanged: (val) {
                      setState(() => strokeWidth = val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget colorBtn(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedColor = color;
          isEraser = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(5),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<List<DrawingPoint>> strokes;

  DrawingPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (var stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(
          stroke[i].offset,
          stroke[i + 1].offset,
          stroke[i].paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}