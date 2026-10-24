import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../model/cube_model.dart';
import '../render/rubik_3d_view.dart';
import 'rubik_color_detector.dart';

/// Dữ liệu định hướng chuẩn quốc tế và la bàn cho từng mặt Rubik
class FaceScanInfo {
  final String key;
  final String title;
  final String instruction;
  final Color centerColor;
  final String centerName;
  // 4 mặt tiếp giáp trên khung ngắm
  final String topNeighbor;
  final Color topNeighborColor;
  final String bottomNeighbor;
  final Color bottomNeighborColor;
  final String leftNeighbor;
  final Color leftNeighborColor;
  final String rightNeighbor;
  final Color rightNeighborColor;
  // Mẹo cầm chống xoay sai góc
  final String holdTip;
  // Góc quay cho mô hình 3D mini
  final double previewPitch;
  final double previewYaw;

  const FaceScanInfo({
    required this.key,
    required this.title,
    required this.instruction,
    required this.centerColor,
    required this.centerName,
    required this.topNeighbor,
    required this.topNeighborColor,
    required this.bottomNeighbor,
    required this.bottomNeighborColor,
    required this.leftNeighbor,
    required this.leftNeighborColor,
    required this.rightNeighbor,
    required this.rightNeighborColor,
    required this.holdTip,
    required this.previewPitch,
    required this.previewYaw,
  });
}

/// Màn hình Quét Camera 3x3 với nhận diện màu trực tiếp theo thời gian thực (Live Stream)
/// và 9 Điểm Ngắm Thông Minh Co Dãn Cự Ly (Adaptive Target Rings)
class CameraScannerView extends StatefulWidget {
  final Cube3DState initialState;

  const CameraScannerView({
    super.key,
    required this.initialState,
  });

  @override
  State<CameraScannerView> createState() => _CameraScannerViewState();
}

class _CameraScannerViewState extends State<CameraScannerView> {
  final picker = ImagePicker();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _hasCameraError = false;
  bool _showLiveCamera = true;
  bool _isAnalyzing = false;

  // Xử lý luồng Camera Live Stream
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  DateTime _lastFrameTime = DateTime.now();
  LiveColorResult? _liveResult;

  // Cự ly co dãn 9 điểm ngắm (Spread factor: 0.40 -> 0.85)
  double _targetSpread = 0.65;
  double _baseSpread = 0.65;

  // Trình tự 6 mặt chuẩn quốc tế (Quy tắc cố định trục không gian)
  static const List<FaceScanInfo> scanOrder = [
    FaceScanInfo(
      key: 'front',
      title: 'Mặt TRƯỚC (Front)',
      instruction: 'Đặt tâm ĐỎ vào ô chính giữa',
      centerColor: RubikColors.red,
      centerName: 'Đỏ',
      topNeighbor: 'VÀNG',
      topNeighborColor: RubikColors.yellow,
      bottomNeighbor: 'TRẮNG',
      bottomNeighborColor: RubikColors.white,
      leftNeighbor: 'XANH DƯƠNG',
      leftNeighborColor: RubikColors.blue,
      rightNeighbor: 'XANH LÁ',
      rightNeighborColor: RubikColors.green,
      holdTip: 'Đỉnh VÀNG hướng lên trên, đáy TRẮNG hướng xuống dưới.',
      previewPitch: 0.0,
      previewYaw: 0.0,
    ),
    FaceScanInfo(
      key: 'right',
      title: 'Mặt PHẢI (Right)',
      instruction: 'Xoay khối Rubik sang PHẢI 90°',
      centerColor: RubikColors.green,
      centerName: 'Xanh lá',
      topNeighbor: 'VÀNG',
      topNeighborColor: RubikColors.yellow,
      bottomNeighbor: 'TRẮNG',
      bottomNeighborColor: RubikColors.white,
      leftNeighbor: 'ĐỎ',
      leftNeighborColor: RubikColors.red,
      rightNeighbor: 'CAM',
      rightNeighborColor: RubikColors.orange,
      holdTip: 'Vẫn giữ nguyên đỉnh VÀNG ở trên và đáy TRẮNG ở dưới.',
      previewPitch: 0.0,
      previewYaw: -math.pi / 2,
    ),
    FaceScanInfo(
      key: 'back',
      title: 'Mặt SAU (Back)',
      instruction: 'Xoay tiếp sang PHẢI 90° để thấy tâm CAM',
      centerColor: RubikColors.orange,
      centerName: 'Cam',
      topNeighbor: 'VÀNG',
      topNeighborColor: RubikColors.yellow,
      bottomNeighbor: 'TRẮNG',
      bottomNeighborColor: RubikColors.white,
      leftNeighbor: 'XANH LÁ',
      leftNeighborColor: RubikColors.green,
      rightNeighbor: 'XANH DƯƠNG',
      rightNeighborColor: RubikColors.blue,
      holdTip: 'Vẫn giữ nguyên đỉnh VÀNG ở trên và đáy TRẮNG ở dưới.',
      previewPitch: 0.0,
      previewYaw: -math.pi,
    ),
    FaceScanInfo(
      key: 'left',
      title: 'Mặt TRÁI (Left)',
      instruction: 'Xoay tiếp sang PHẢI 90° để thấy tâm XANH DƯƠNG',
      centerColor: RubikColors.blue,
      centerName: 'Xanh dương',
      topNeighbor: 'VÀNG',
      topNeighborColor: RubikColors.yellow,
      bottomNeighbor: 'TRẮNG',
      bottomNeighborColor: RubikColors.white,
      leftNeighbor: 'CAM',
      leftNeighborColor: RubikColors.orange,
      rightNeighbor: 'ĐỎ',
      rightNeighborColor: RubikColors.red,
      holdTip: 'Vẫn giữ nguyên đỉnh VÀNG ở trên và đáy TRẮNG ở dưới.',
      previewPitch: 0.0,
      previewYaw: math.pi / 2,
    ),
    FaceScanInfo(
      key: 'top',
      title: 'Mặt TRÊN (Top)',
      instruction: 'Nghiêng đỉnh Rubik về phía camera để thấy tâm VÀNG',
      centerColor: RubikColors.yellow,
      centerName: 'Vàng',
      topNeighbor: 'CAM',
      topNeighborColor: RubikColors.orange,
      bottomNeighbor: 'ĐỎ',
      bottomNeighborColor: RubikColors.red,
      leftNeighbor: 'XANH DƯƠNG',
      leftNeighborColor: RubikColors.blue,
      rightNeighbor: 'XANH LÁ',
      rightNeighborColor: RubikColors.green,
      holdTip: 'Mép DƯỚI phải giáp mặt ĐỎ, mép TRÊN giáp mặt CAM!',
      previewPitch: -math.pi / 2,
      previewYaw: 0.0,
    ),
    FaceScanInfo(
      key: 'bottom',
      title: 'Mặt DƯỚI (Bottom)',
      instruction: 'Hất đáy Rubik lên phía camera để thấy tâm TRẮNG',
      centerColor: RubikColors.white,
      centerName: 'Trắng',
      topNeighbor: 'ĐỎ',
      topNeighborColor: RubikColors.red,
      bottomNeighbor: 'CAM',
      bottomNeighborColor: RubikColors.orange,
      leftNeighbor: 'XANH DƯƠNG',
      leftNeighborColor: RubikColors.blue,
      rightNeighbor: 'XANH LÁ',
      rightNeighborColor: RubikColors.green,
      holdTip: 'Mép TRÊN phải giáp mặt ĐỎ, mép DƯỚI giáp mặt CAM!',
      previewPitch: math.pi / 2,
      previewYaw: 0.0,
    ),
  ];

  int _currentStep = 0;
  late Cube3DState _workingState;
  List<Color> _currentFaceStickers = [];
  File? _lastPhoto;
  DetectedFaceColors? _lastDetected;
  Color _selectedPaletteColor = RubikColors.red;

  @override
  void initState() {
    super.initState();
    _workingState = widget.initialState.clone();
    _loadCurrentFace();
    _initLiveCamera();
  }

  /// Ảnh tạm (ảnh gốc + ảnh cắt vuông) — xoá khi rời màn hình
  final List<String> _tempFiles = [];

  @override
  void dispose() {
    // CameraController.dispose() tự dừng image stream; không gọi stopImageStream
    // bất đồng bộ trước đó vì controller sẽ bị huỷ ngay sau.
    _isStreaming = false;
    _cameraController?.dispose();
    _cameraController = null;
    _deleteTempFiles();
    super.dispose();
  }

  void _deleteTempFiles() {
    for (final path in _tempFiles) {
      File(path).delete().catchError((_) => File(path));
    }
    _tempFiles.clear();
  }

  /// Khởi tạo camera và tự động kích hoạt Live Stream
  Future<void> _initLiveCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        final backCamera = _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );

        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraReady = true;
            _hasCameraError = false;
          });
          _startLiveStream();
        }
      }
    } catch (e) {
      debugPrint('Live camera initialization error: $e');
      if (mounted) {
        setState(() {
          _hasCameraError = true;
          _isCameraReady = false;
        });
      }
    }
  }

  /// Bắt đầu lắng nghe luồng ảnh Camera Image Stream để trích xuất màu trực tiếp
  Future<void> _startLiveStream() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_isStreaming) return;

    try {
      _isStreaming = true;
      await _cameraController!.startImageStream((CameraImage image) {
        if (!_showLiveCamera || _isAnalyzing) return;

        final now = DateTime.now();
        // Giới hạn 100ms một lần (khoảng 10 fps) để tiết kiệm pin và đảm bảo UI 60 FPS mượt mà
        if (_isProcessingFrame ||
            now.difference(_lastFrameTime).inMilliseconds < 100) {
          return;
        }

        _isProcessingFrame = true;
        _lastFrameTime = now;

        try {
          final normalizedPoints =
              RubikColorDetector.computeNormalizedPoints(_targetSpread);
          final sensorOrientation =
              _cameraController!.description.sensorOrientation;

          final result = RubikColorDetector.extractColorsFromCameraImage(
            image: image,
            normalizedPoints: normalizedPoints,
            sensorOrientation: sensorOrientation,
            expectedCenterColor: scanOrder[_currentStep].centerColor,
          );

          if (mounted && _showLiveCamera) {
            setState(() {
              _liveResult = result;
              _currentFaceStickers = List.from(result.classifiedColors);
            });
          }
        } catch (err) {
          debugPrint('Live frame processing error: $err');
        } finally {
          _isProcessingFrame = false;
        }
      });
    } catch (e) {
      debugPrint('Error starting image stream: $e');
      _isStreaming = false;
    }
  }

  /// Dừng lắng nghe luồng ảnh camera
  Future<void> _stopLiveStream() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (!_isStreaming) return;

    try {
      _isStreaming = false;
      await _cameraController!.stopImageStream();
    } catch (e) {
      debugPrint('Error stopping image stream: $e');
    }
  }

  void _loadCurrentFace() {
    final key = scanOrder[_currentStep].key;
    _currentFaceStickers = List.from(_workingState.faces[key]!);
    _lastPhoto = null;
    _lastDetected = null;
    _showLiveCamera = true;
    _selectedPaletteColor = scanOrder[_currentStep].centerColor;
    if (_isCameraReady && !_isStreaming) {
      _startLiveStream();
    }
  }

  /// Chụp & phân tích ảnh tĩnh dự phòng từ camera
  /// Chụp & phân tích ảnh tĩnh dự phòng từ camera
  Future<void> _captureStillPhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _pickImage(ImageSource.camera);
      return;
    }
    if (_isAnalyzing) return;

    try {
      setState(() {
        _isAnalyzing = true;
      });

      // Tạm dừng stream trước khi chụp ảnh tĩnh
      await _stopLiveStream();

      final XFile photo = await _cameraController!.takePicture();
      _tempFiles.add(photo.path);

      // Cắt ảnh chụp thành hình vuông chính tâm (Center Square Crop) để trùng khớp 100% với khung ngắm camera
      final croppedPhotoFile =
          await RubikColorDetector.cropToSquareImage(photo.path);
      _tempFiles.add(croppedPhotoFile.path);

      final detected = await RubikColorDetector.processImage(
        croppedPhotoFile.path,
        expectedCenterColor: scanOrder[_currentStep].centerColor,
        spread: _targetSpread,
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _lastPhoto = croppedPhotoFile;
          _lastDetected = detected;
          // Đồng bộ màu trực tiếp từ kết quả phân tích ảnh chụp thực tế
          _currentFaceStickers = List.from(detected.colors);
          _showLiveCamera = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chụp: $e')),
        );
      }
    }
  }

  /// Chọn ảnh từ thư viện
  Future<void> _pickImage(ImageSource source) async {
    try {
      await _stopLiveStream();

      final photo = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (photo == null) {
        if (_showLiveCamera) _startLiveStream();
        return;
      }

      setState(() {
        _isAnalyzing = true;
      });

      // Cắt ảnh chọn thành hình vuông chính tâm để chuẩn hóa tỷ lệ hiển thị
      final croppedPhotoFile =
          await RubikColorDetector.cropToSquareImage(photo.path);
      _tempFiles.add(croppedPhotoFile.path);

      final detected = await RubikColorDetector.processImage(
        croppedPhotoFile.path,
        expectedCenterColor: scanOrder[_currentStep].centerColor,
        spread: _targetSpread,
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _lastPhoto = croppedPhotoFile;
          _lastDetected = detected;
          _currentFaceStickers = List.from(detected.colors);
          _showLiveCamera = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  /// Xoay 90° cùng chiều kim đồng hồ
  void _rotateGridCW() {
    setState(() {
      final s = List<Color>.from(_currentFaceStickers);
      _currentFaceStickers = [
        s[6],
        s[3],
        s[0],
        s[7],
        s[4],
        s[1],
        s[8],
        s[5],
        s[2],
      ];
    });
  }

  /// Xoay 90° ngược chiều kim đồng hồ
  void _rotateGridCCW() {
    setState(() {
      final s = List<Color>.from(_currentFaceStickers);
      _currentFaceStickers = [
        s[2],
        s[5],
        s[8],
        s[1],
        s[4],
        s[7],
        s[0],
        s[3],
        s[6],
      ];
    });
  }

  /// Xoay 180° đảo chiều
  void _rotateGrid180() {
    setState(() {
      final s = List<Color>.from(_currentFaceStickers);
      _currentFaceStickers = [
        s[8],
        s[7],
        s[6],
        s[5],
        s[4],
        s[3],
        s[2],
        s[1],
        s[0],
      ];
    });
  }

  /// Chốt màu mặt hiện tại và chuyển sang mặt tiếp theo
  void _confirmAndNext() {
    final key = scanOrder[_currentStep].key;
    for (int i = 0; i < 9; i++) {
      _workingState.setColor(key, i, _currentFaceStickers[i]);
    }

    if (_currentStep < scanOrder.length - 1) {
      setState(() {
        _currentStep++;
        _loadCurrentFace();
      });
    } else {
      Navigator.pop(context, _workingState);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _loadCurrentFace();
      });
    }
  }

  void _showHelpDialog(FaceScanInfo info) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: info.centerColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 1.5),
              ),
            ),
            const SizedBox(width: 8),
            Text(info.title,
                style: const TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Rubik3DView(
                  state: _workingState,
                  size: 120,
                  enableInteraction: true,
                  initialPitch: info.previewPitch,
                  initialYaw: info.previewYaw,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.push_pin_rounded,
                    size: 18, color: Colors.amberAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(info.instruction,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.amberAccent)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.explore_rounded, size: 18, color: Colors.cyanAccent),
                SizedBox(width: 6),
                Text('Hướng tiếp giáp 4 cạnh:',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.cyanAccent,
                        fontSize: 14)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Phía TRÊN: Mặt ${info.topNeighbor}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                  Text('• Phía DƯỚI: Mặt ${info.bottomNeighbor}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                  Text('• Phía TRÁI: Mặt ${info.leftNeighbor}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                  Text('• Phía PHẢI: Mặt ${info.rightNeighbor}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 16, color: Colors.amberAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      info.holdTip,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu',
                style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentInfo = scanOrder[_currentStep];
    final isLastStep = _currentStep == scanOrder.length - 1;
    final isCenterColorMatch =
        _currentFaceStickers[4] == currentInfo.centerColor;

    return PopScope(
      // Đã chốt ít nhất 1 mặt → hỏi trước khi thoát để không mất kết quả
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askBeforeExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF141416),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E22),
          elevation: 0,
          foregroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: currentInfo.centerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Mặt ${_currentStep + 1}/6: ${currentInfo.centerName}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.amberAccent),
              tooltip: 'Xem hướng dẫn xoay mặt',
              onPressed: () => _showHelpDialog(currentInfo),
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.greenAccent),
              tooltip: 'Hoàn tất & thoát',
              onPressed: () {
                final key = scanOrder[_currentStep].key;
                for (int i = 0; i < 9; i++) {
                  _workingState.setColor(key, i, _currentFaceStickers[i]);
                }
                Navigator.pop(context, _workingState);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight;
              // Tính toán kích thước camera vừa vặn tỉ lệ màn hình và chừa khoảng trống cho 4 nhãn định hướng bên ngoài
              // Chiều ngang còn lại sau lề 2×14, 2 nhãn bên (tối đa 60) và 2 khoảng 6
              final cameraSize = math
                  .min(constraints.maxWidth - 28 - 120 - 12, availableHeight * 0.31)
                  .clamp(160.0, 260.0);

              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14.0, vertical: 4.0),
                  child: Column(
                    children: [
                      // 1. Thanh tiến trình 6 mặt
                      _buildModernProgressSegments(),
                      const SizedBox(height: 4),

                      // 2. Banner mẹo định vị nhanh
                      _buildOrientationTipBanner(currentInfo),
                      const SizedBox(height: 6),

                      // 3. Khung ngắm Camera Pro với 9 Vòng tròn ngắm Dạ Quang (Adaptive Target Rings)
                      _buildImmersiveCameraViewfinder(currentInfo, cameraSize),
                      const SizedBox(height: 6),

                      // 4. Thanh trượt Cự Ly Rubik: Gần <---> Xa (Co dãn 9 điểm ngắm)
                      _buildSpreadControlSlider(),
                      const SizedBox(height: 8),

                      // 5. Bảng điều khiển kết quả nhận diện & chỉnh màu nhanh
                      _buildRecognitionDashboard(
                          currentInfo, isCenterColorMatch),
                      const SizedBox(height: 8),

                      // 6. Thanh công cụ hành động dưới đáy
                      _buildBottomActionButtons(isLastStep),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _askBeforeExit() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        icon: const Icon(Icons.save_outlined, color: Colors.amberAccent),
        title: const Text('Thoát màn quét?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn đã chốt $_currentStep/6 mặt. Muốn giữ kết quả đã quét không?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('Ở lại', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Bỏ kết quả',
                style: TextStyle(color: Colors.redAccent)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: const Text('Giữ & thoát'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'keep') {
      Navigator.pop(context, _workingState);
    } else if (choice == 'discard') {
      Navigator.pop(context);
    }
  }

  // Nhãn vị trí mặt (thay cho chữ cái đầu màu — "Xanh lá"/"Xanh dương" đều là "X")
  static const _segmentLabels = {
    'front': 'Trước',
    'right': 'Phải',
    'back': 'Sau',
    'left': 'Trái',
    'top': 'Trên',
    'bottom': 'Dưới',
  };

  /// 1. Thanh tiến trình 6 mặt tối giản
  Widget _buildModernProgressSegments() {
    return Row(
      children: List.generate(scanOrder.length, (index) {
        final info = scanOrder[index];
        final isDone = index < _currentStep;
        final isCurrent = index == _currentStep;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              final key = scanOrder[_currentStep].key;
              for (int i = 0; i < 9; i++) {
                _workingState.setColor(key, i, _currentFaceStickers[i]);
              }
              setState(() {
                _currentStep = index;
                _loadCurrentFace();
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              height: 44,
              decoration: BoxDecoration(
                color: isCurrent
                    ? info.centerColor.withValues(alpha: 0.9)
                    : isDone
                        ? info.centerColor.withValues(alpha: 0.4)
                        : Colors.white10,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCurrent ? Colors.white : Colors.transparent,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _segmentLabels[info.key] ?? info.centerName[0],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: (isCurrent || isDone)
                      ? (info.centerColor == RubikColors.white ||
                              info.centerColor == RubikColors.yellow
                          ? Colors.black87
                          : Colors.white)
                      : Colors.white54,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 2. Banner định hướng cầm Rubik + Mô hình 3D mini
  Widget _buildOrientationTipBanner(FaceScanInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: Colors.indigo.shade400.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Mô hình 3D mini trực quan (được chuyển từ trong camera ra đây để không che góc camera)
          GestureDetector(
            onTap: () => _showHelpDialog(info),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.indigoAccent.withValues(alpha: 0.6)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Rubik3DView(
                  state: _workingState,
                  size: 32,
                  enableInteraction: false,
                  initialPitch: info.previewPitch,
                  initialYaw: info.previewYaw,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              info.holdTip,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => _showHelpDialog(info),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.indigo.shade600,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Xem 3D',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Khung ngắm Camera Pro với 9 Vòng tròn ngắm Dạ Quang (Adaptive Target Rings)
  /// Toàn bộ 4 nhãn màu cạnh (Đỉnh, Đáy, Trái, Phải) được đưa ra BÊN NGOÀI vùng camera
  /// Vùng camera bên trong hoàn toàn thông thoáng 100%, không bị che khuất
  Widget _buildImmersiveCameraViewfinder(FaceScanInfo info, double size) {
    final normalizedPoints =
        RubikColorDetector.computeNormalizedPoints(_targetSpread);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Nhãn ĐỈNH (BÊN NGOÀI, PHÍA TRÊN KHUNG CAMERA)
        _hudCompassTag('▲ ĐỈNH: ${info.topNeighbor}', info.topNeighborColor),
        const SizedBox(height: 5),

        // 2. Hàng ngang: [Nhãn TRÁI] - [CAMERA SẠCH 100%] - [Nhãn PHẢI]
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Nhãn TRÁI (BÊN NGOÀI, BÊN TRÁI KHUNG CAMERA)
            _hudSideCompassTag('◀', info.leftNeighbor, info.leftNeighborColor,
                isLeft: true),
            const SizedBox(width: 6),

            // Khung hình camera sạch sẽ (chỉ chứa hình ảnh thực tế + 9 vòng tròn ngắm dạ quang)
            GestureDetector(
              onScaleStart: (_) {
                _baseSpread = _targetSpread;
              },
              onScaleUpdate: (details) {
                setState(() {
                  _targetSpread =
                      (_baseSpread * details.scale).clamp(0.40, 0.85);
                });
              },
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.indigoAccent.withValues(alpha: 0.6),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Luồng camera hoặc ảnh tĩnh
                      if (_isAnalyzing)
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                  color: Colors.cyanAccent),
                              SizedBox(height: 8),
                              Text('Đang phân tích...',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        )
                      else if (!_showLiveCamera &&
                          _lastPhoto != null &&
                          _lastPhoto!.existsSync()) ...[
                        Image.file(_lastPhoto!, fit: BoxFit.cover),
                        // Điểm ngắm trên ảnh tĩnh
                        CustomPaint(
                          painter: _AdaptiveTargetRingsPainter(
                            normalizedPoints: _lastDetected?.normalizedPoints ??
                                normalizedPoints,
                            liveColors: _currentFaceStickers,
                            liveRawColors: null,
                            expectedCenterColor: info.centerColor,
                            isLiveMode: false,
                            spread: _targetSpread,
                          ),
                        ),
                      ] else if (_isCameraReady &&
                          _cameraController != null) ...[
                        ClipRect(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: size,
                              height: size *
                                  (_cameraController!.value.aspectRatio > 0
                                      ? _cameraController!.value.aspectRatio
                                      : 1.333),
                              child: CameraPreview(_cameraController!),
                            ),
                          ),
                        ),
                        // Điểm ngắm Dạ Quang thời gian thực trên Camera Live
                        CustomPaint(
                          painter: _AdaptiveTargetRingsPainter(
                            normalizedPoints: normalizedPoints,
                            liveColors: _liveResult?.classifiedColors ??
                                _currentFaceStickers,
                            liveRawColors: _liveResult?.rawRgbColors,
                            expectedCenterColor: info.centerColor,
                            isLiveMode: true,
                            spread: _targetSpread,
                          ),
                        ),
                      ] else ...[
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_off_outlined,
                                  color: Colors.white38, size: 32),
                              const SizedBox(height: 4),
                              Text(
                                _hasCameraError
                                    ? 'Camera không khả dụng'
                                    : 'Đang mở Camera...',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),
            // Nhãn PHẢI (BÊN NGOÀI, BÊN PHẢI KHUNG CAMERA)
            _hudSideCompassTag('▶', info.rightNeighbor, info.rightNeighborColor,
                isLeft: false),
          ],
        ),
        const SizedBox(height: 5),

        // 3. Nhãn ĐÁY (BÊN NGOÀI, PHÍA DƯỚI KHUNG CAMERA)
        _hudCompassTag(
            '▼ ĐÁY: ${info.bottomNeighbor}', info.bottomNeighborColor),
      ],
    );
  }

  /// 4. Thanh trượt Cự Ly Rubik: Gần <---> Xa (Co dãn 9 điểm ngắm)
  Widget _buildSpreadControlSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.zoom_out, size: 15, color: Colors.white60),
          const SizedBox(width: 4),
          const Text('Cự ly Rubik:',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.cyanAccent,
                thumbColor: Colors.cyanAccent,
                inactiveTrackColor: Colors.white24,
              ),
              child: Slider(
                value: _targetSpread,
                min: 0.40,
                max: 0.85,
                onChanged: (val) {
                  setState(() {
                    _targetSpread = val;
                  });
                },
              ),
            ),
          ),
          const Text('Gần',
              style: TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(width: 4),
          const Icon(Icons.zoom_in, size: 15, color: Colors.white60),
        ],
      ),
    );
  }

  /// Tag la bàn HUD ngang (Đỉnh / Đáy) đặt bên ngoài khung camera
  Widget _hudCompassTag(String text, Color color) {
    final isLight = color == RubikColors.white || color == RubikColors.yellow;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white30, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Tag la bàn HUD dọc (Trái / Phải) đặt bên ngoài khung camera
  Widget _hudSideCompassTag(String arrow, String name, Color color,
      {required bool isLeft}) {
    final isLight = color == RubikColors.white || color == RubikColors.yellow;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Container(
      constraints: const BoxConstraints(minWidth: 48, maxWidth: 60),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white30, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            arrow,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Bảng điều khiển kết quả: Lưới 3x3 kết quả + Nút xoay 90° + Bút màu
  Widget _buildRecognitionDashboard(FaceScanInfo info, bool isCenterOk) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCenterOk
              ? Colors.white12
              : Colors.redAccent.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Trạng thái tâm
          Row(
            children: [
              Icon(
                isCenterOk ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
                color: isCenterOk ? Colors.greenAccent : Colors.redAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isCenterOk
                      ? 'Đúng tâm ${info.centerName}'
                      : 'Lệch tâm hoặc sai hướng!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isCenterOk ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Xoay lưới khi mặt bị quét sai hướng
          Row(
            children: [
              _gridRotateButton(
                  Icons.rotate_left_rounded, 'Xoay trái', _rotateGridCCW),
              const SizedBox(width: 6),
              _gridRotateButton(
                  Icons.swap_vert_rounded, 'Xoay 180°', _rotateGrid180),
              const SizedBox(width: 6),
              _gridRotateButton(
                  Icons.rotate_right_rounded, 'Xoay phải', _rotateGridCW),
            ],
          ),
          const SizedBox(height: 6),

          // Lưới 3x3 kết quả + Bút màu đặt ngang nhau
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lưới 3x3
              Container(
                width: 108,
                height: 108,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, idx) {
                    final color = _currentFaceStickers[idx];
                    final isCenter = idx == 4;

                    return GestureDetector(
                      onTap: () {
                        if (!isCenter) {
                          setState(() {
                            _currentFaceStickers[idx] = _selectedPaletteColor;
                          });
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isCenter ? Colors.black : Colors.white30,
                            width: isCenter ? 2.0 : 0.8,
                          ),
                        ),
                        child: isCenter
                            ? const Center(
                                child: Icon(Icons.lock,
                                    size: 10, color: Colors.black54))
                            : null,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Bảng 6 bút màu chọn nhanh & Nút chụp tĩnh đưa xuống khoảng trống bên dưới
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Chạm ô để đổi màu thủ công:',
                        style: TextStyle(fontSize: 12, color: Colors.white60)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 0,
                      runSpacing: 0,
                      children: [
                        RubikColors.white,
                        RubikColors.yellow,
                        RubikColors.red,
                        RubikColors.orange,
                        RubikColors.green,
                        RubikColors.blue,
                      ].map((c) {
                        final isSelected = _selectedPaletteColor == c;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _selectedPaletteColor = c;
                            });
                          },
                          child: SizedBox.square(
                            dimension: 48,
                            child: Center(
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.cyanAccent
                                        : Colors.black45,
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                              color: Colors.cyanAccent
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 4)
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        size: 16, color: Colors.black87)
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 8),

                    // KHOẢNG TRỐNG BÊN DƯỚI: Nút Chụp ảnh tĩnh / Bật Live Cam
                    Row(
                      children: [
                        InkWell(
                          onTap: _isAnalyzing
                              ? null
                              : () {
                                  if (_showLiveCamera) {
                                    _captureStillPhoto();
                                  } else {
                                    setState(() {
                                      _showLiveCamera = true;
                                    });
                                    _startLiveStream();
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _showLiveCamera
                                    ? [
                                        const Color(0xFF1565C0),
                                        const Color(0xFF1E88E5)
                                      ]
                                    : [
                                        const Color(0xFF00695C),
                                        const Color(0xFF00897B)
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _showLiveCamera
                                    ? Colors.cyanAccent
                                    : Colors.tealAccent,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_showLiveCamera
                                          ? Colors.blue
                                          : Colors.teal)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showLiveCamera
                                      ? Icons.camera_alt
                                      : Icons.videocam,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _showLiveCamera
                                      ? 'Chụp tĩnh'
                                      : 'Bật Live Cam',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!_showLiveCamera) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: _isAnalyzing ? null : _captureStillPhoto,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh,
                                      size: 13, color: Colors.white70),
                                  SizedBox(width: 3),
                                  Text('Chụp lại',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.white70)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gridRotateButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white70),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 6. Thanh công cụ điều hướng dưới đáy
  Widget _buildBottomActionButtons(bool isLastStep) {
    return Row(
      children: [
        // Nút mở thư viện
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed:
              _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
          child: const Icon(Icons.photo_library, size: 18),
        ),
        const SizedBox(width: 6),

        if (_currentStep > 0) ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _previousStep,
            child: const Text('Trước', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
        ],

        // Nút CHỐT MẶT NÀY & KẾ TIẾP
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isLastStep ? Colors.teal.shade600 : Colors.indigo.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 3,
            ),
            onPressed: _confirmAndNext,
            icon: Icon(isLastStep ? Icons.check_circle : Icons.arrow_forward,
                size: 18),
            label: Text(
              isLastStep ? 'CHỐT & XEM LỜI GIẢI' : 'CHỐT MẶT NÀY & TIẾP THEO',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3),
            ),
          ),
        ),
      ],
    );
  }
}

/// Painter 9 Vòng Tròn Định Vị Dạ Quang Thông Minh (Adaptive Target Rings)
class _AdaptiveTargetRingsPainter extends CustomPainter {
  final List<Offset> normalizedPoints;
  final List<Color>? liveColors;
  final List<Color>? liveRawColors;
  final Color expectedCenterColor;
  final bool isLiveMode;
  final double spread;

  _AdaptiveTargetRingsPainter({
    required this.normalizedPoints,
    required this.liveColors,
    required this.liveRawColors,
    required this.expectedCenterColor,
    required this.isLiveMode,
    required this.spread,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Vẽ 4 góc L-Brackets bao quát quanh khối Rubik
    final boxSize = width * spread;
    final startX = (width - boxSize) / 2;
    final startY = (height - boxSize) / 2;
    final endX = startX + boxSize;
    final endY = startY + boxSize;

    final bracketPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final bracketLen = (boxSize * 0.12).clamp(12.0, 24.0);

    // Góc trên - trái
    canvas.drawLine(Offset(startX, startY), Offset(startX + bracketLen, startY),
        bracketPaint);
    canvas.drawLine(Offset(startX, startY), Offset(startX, startY + bracketLen),
        bracketPaint);

    // Góc trên - phải
    canvas.drawLine(
        Offset(endX, startY), Offset(endX - bracketLen, startY), bracketPaint);
    canvas.drawLine(
        Offset(endX, startY), Offset(endX, startY + bracketLen), bracketPaint);

    // Góc dưới - trái
    canvas.drawLine(
        Offset(startX, endY), Offset(startX + bracketLen, endY), bracketPaint);
    canvas.drawLine(
        Offset(startX, endY), Offset(startX, endY - bracketLen), bracketPaint);

    // Góc dưới - phải
    canvas.drawLine(
        Offset(endX, endY), Offset(endX - bracketLen, endY), bracketPaint);
    canvas.drawLine(
        Offset(endX, endY), Offset(endX, endY - bracketLen), bracketPaint);

    // 2. Vẽ 9 điểm ngắm thông minh có vòng đai dạ quang (Glow Halo)
    for (int i = 0; i < normalizedPoints.length; i++) {
      final norm = normalizedPoints[i];
      final cx = norm.dx * width;
      final cy = norm.dy * height;
      final center = Offset(cx, cy);

      final isCenterPiece = i == 4;
      final ringRadius = isCenterPiece ? 13.0 : 10.5;

      Color ringGlowColor = Colors.white;
      Color innerFillColor = Colors.white24;

      if (liveColors != null && i < liveColors!.length) {
        ringGlowColor = liveColors![i];
        innerFillColor = ringGlowColor.withValues(alpha: 0.45);
      }

      // Quầng sáng dạ quang (Glow Halo)
      final haloPaint = Paint()
        ..color = ringGlowColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, ringRadius + 2.5, haloPaint);

      // Lõi bên trong
      final fillPaint = Paint()
        ..color = innerFillColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, ringRadius, fillPaint);

      // Vòng tròn viền chính
      final borderPaint = Paint()
        ..color = ringGlowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCenterPiece ? 2.5 : 1.8;
      canvas.drawCircle(center, ringRadius, borderPaint);

      // Viền đen mảnh ngoài cùng để tương phản trên nền sáng
      final outerContrastPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawCircle(center, ringRadius + 1.2, outerContrastPaint);

      // Tâm chữ thập mảnh (+)
      final crosshairPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      const chLen = 3.0;
      canvas.drawLine(
          Offset(cx - chLen, cy), Offset(cx + chLen, cy), crosshairPaint);
      canvas.drawLine(
          Offset(cx, cy - chLen), Offset(cx, cy + chLen), crosshairPaint);

      // Nếu là viên Tâm (index 4), vẽ thêm vòng đai tiêu điểm màu tâm chuẩn
      if (isCenterPiece) {
        final targetRingPaint = Paint()
          ..color = expectedCenterColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6;
        canvas.drawCircle(center, ringRadius + 4.0, targetRingPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AdaptiveTargetRingsPainter oldDelegate) => true;
}
