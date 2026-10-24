import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/models.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/services/shell_navigation.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/player_card.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../profile/player_profile_sheet.dart';
import 'challenges_tab.dart';
import 'conversations_tab.dart';
import 'friends_controller.dart';
import 'friends_tab.dart';
import 'social_summary_controller.dart';

/// Bạn bè v2: tìm người chơi, danh sách bạn (online), lời mời kết bạn,
/// tin nhắn và thách đấu không đồng thời.
///
/// [active] cho biết tab đang hiển thị trong khung chính; khi vừa được chọn
/// lại và dữ liệu đã cũ (> 30 giây) thì tải lại một lần.
class SocialScreen extends StatefulWidget {
  final bool active;
  final FriendsSegment initialSegment;
  const SocialScreen({
    super.key,
    this.active = true,
    this.initialSegment = FriendsSegment.friends,
  });

  @override
  State<SocialScreen> createState() => SocialScreenState();
}

class SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  final _challengesKey = GlobalKey<ChallengesTabState>();
  final _conversationsKey = GlobalKey<ConversationsTabState>();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late final TabController _tabs = TabController(
      length: FriendsSegment.values.length,
      vsync: this,
      initialIndex: widget.initialSegment.index)
    ..addListener(() {
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });

  bool _built(FriendsSegment s) =>
      s.index == _tabs.index || _visited.contains(s.index);

  /// Tab Tin nhắn / Thách đấu chỉ dựng (và gọi API) khi được mở lần đầu.
  final Set<int> _visited = {};

  FriendsController? _friends;
  int? _friendsUserId;
  DateTime _lastLoad = DateTime.now();

  Timer? _debounce;
  int _searchId = 0;
  String _query = '';
  bool _searching = false;
  String? _searchError;
  List<UserSummary> _results = const [];

  static const _staleAfter = Duration(seconds: 30);

  /// Chuyển sang một phân đoạn (do thông báo / điều hướng yêu cầu).
  void showSegment(FriendsSegment s) {
    _tabs.index = s.index;
    if (_query.isNotEmpty) _clearSearch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthController>(context);
    final uid = auth.isAuthenticated ? auth.currentUser?.userId : null;
    if (uid == _friendsUserId && (uid == null) == (_friends == null)) return;
    _friends?.dispose();
    _friendsUserId = uid;
    if (uid == null) {
      _friends = null;
    } else {
      RealtimeService? rt;
      try {
        rt = context.read<RealtimeService>();
      } catch (_) {}
      _friends = FriendsController(api: context.read<ApiClient>(), realtime: rt)
        ..addListener(_syncBadge)
        ..load();
    }
  }

  void _syncBadge() {
    final f = _friends;
    if (f == null || f.loading) return;
    _summary?.setIncomingFriendRequests(f.incoming.length);
  }

  @override
  void didUpdateWidget(SocialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        !oldWidget.active &&
        DateTime.now().difference(_lastLoad) > _staleAfter) {
      _lastLoad = DateTime.now();
      _friends?.load();
      _challengesKey.currentState?.load();
      _conversationsKey.currentState?.load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _tabs.dispose();
    _friends?.dispose();
    super.dispose();
  }

  SocialSummaryController? get _summary {
    try {
      return context.read<SocialSummaryController>();
    } catch (_) {
      return null;
    }
  }

  // ---- tìm kiếm ----

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() {
      _query = q;
      _searchError = null;
      if (q.length < 2) {
        _results = const [];
        _searching = false;
        _searchId++;
      }
    });
    if (q.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final id = ++_searchId;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final r = await context.read<ApiClient>().searchUsers(q);
      if (!mounted || id != _searchId) return;
      final me = context.read<AuthController>().currentUser?.userId;
      setState(() {
        _results = [
          for (final u in r)
            if (u.userId != me) u
        ];
        _searching = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _searching = false;
        _searchError = e.message;
      });
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _query = '';
      _results = const [];
      _searching = false;
      _searchError = null;
      _searchId++;
    });
  }

  void _findFriends() {
    _tabs.index = FriendsSegment.friends.index;
    _searchFocus.requestFocus();
  }

  Future<void> _openPlayer(UserSummary u) async {
    FocusScope.of(context).unfocus();
    await showPlayerProfileSheet(context, u);
    if (mounted) _friends?.load();
  }

  Future<void> _login() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    Widget body;
    if (auth.status == AuthStatus.unknown) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!auth.isAuthenticated) {
      body = EmptyState(
        icon: Icons.people_rounded,
        title: 'Đăng nhập để chơi cùng bạn bè',
        message:
            'Kết bạn, nhắn tin và mời nhau đấu trực tiếp. Cần có tài khoản.',
        actionLabel: 'Đăng nhập',
        onAction: _login,
      );
    } else {
      body = _buildLoggedIn(context);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Bạn bè')),
      body: body,
    );
  }

  Widget _buildLoggedIn(BuildContext context) {
    final searching = _query.isNotEmpty;
    final friends = _friends;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm,
              AppSpacing.screen, AppSpacing.xs),
          child: TextField(
            controller: _search,
            focusNode: _searchFocus,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm người chơi',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xoá từ khoá',
                      constraints: const BoxConstraints(
                          minWidth: kMinTouchTarget,
                          minHeight: kMinTouchTarget),
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        if (!searching)
          ListenableBuilder(
            listenable: friends ?? _tabs,
            builder: (context, _) => TabBar(
              controller: _tabs,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: [
                const Tab(height: kMinTouchTarget, text: 'Bạn bè'),
                Tab(
                  height: kMinTouchTarget,
                  child: Badge(
                    isLabelVisible: (friends?.incoming.length ?? 0) > 0,
                    label: Text('${friends?.incoming.length ?? 0}'),
                    offset: const Offset(10, -6),
                    child: const Text('Lời mời'),
                  ),
                ),
                const Tab(height: kMinTouchTarget, text: 'Tin nhắn'),
                const Tab(height: kMinTouchTarget, text: 'Thách đấu'),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Giữ nguyên tab khi đang tìm kiếm để không phải tải lại
              Offstage(
                offstage: searching,
                child: ListenableBuilder(
                  listenable:
                      Listenable.merge([_tabs, if (friends != null) friends]),
                  builder: (context, _) {
                    _visited.add(_tabs.index);
                    return IndexedStack(
                      index: _tabs.index,
                      children: [
                        friends == null
                            ? const SizedBox.shrink()
                            : FriendsList(
                                controller: friends,
                                onFindFriends: _findFriends),
                        friends == null
                            ? const SizedBox.shrink()
                            : RequestsList(
                                controller: friends,
                                onFindFriends: _findFriends),
                        if (_built(FriendsSegment.messages))
                          ConversationsTab(
                            key: _conversationsKey,
                            onUnreadCount: (n) =>
                                _summary?.setUnreadMessages(n),
                          )
                        else
                          const SizedBox.shrink(),
                        if (_built(FriendsSegment.challenges))
                          ChallengesTab(
                            key: _challengesKey,
                            onCounts: (incoming, active) =>
                                _summary?.setChallengeCounts(
                                    incoming: incoming, active: active),
                          )
                        else
                          const SizedBox.shrink(),
                      ],
                    );
                  },
                ),
              ),
              if (searching) _buildResults(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (_query.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Nhập ít nhất 2 ký tự để tìm.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    if (_searching) return const Center(child: CircularProgressIndicator());
    if (_searchError != null) {
      return ErrorState(
          message: _searchError!, onRetry: () => _runSearch(_query));
    }
    if (_results.isEmpty) {
      return const EmptyState(
        icon: Icons.person_search_rounded,
        title: 'Không tìm thấy người chơi',
        message: 'Thử tên đăng nhập hoặc họ tên khác.',
      );
    }
    final friends = _friends;
    return ListenableBuilder(
      listenable: friends ?? _tabs,
      builder: (context, _) => ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _results.length,
        itemBuilder: (context, i) {
          final u = _results[i];
          final name = (u.fullName != null && u.fullName!.trim().isNotEmpty)
              ? u.fullName!.trim()
              : u.username;
          final rel = friends?.relationOf(u.userId) ?? Relationship.none;
          return Semantics(
            button: true,
            label: '$name, @${u.username}. Chạm để xem hồ sơ',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => _openPlayer(u),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: AppSpacing.screen,
                      right: AppSpacing.screen,
                      top: AppSpacing.xs,
                      bottom: AppSpacing.xs),
                  child: PlayerCard(
                    name: name,
                    username: u.username,
                    trailing: _relationAction(context, u, rel),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _relationAction(
      BuildContext context, UserSummary u, Relationship rel) {
    final f = _friends;
    final scheme = Theme.of(context).colorScheme;
    const size = Size(kMinTouchTarget, kMinTouchTarget);
    Future<void> run(Future<bool> Function() a, String ok) async {
      final done = await a();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content:
                Text(done ? ok : (f?.actionError ?? 'Không thực hiện được'))));
    }

    switch (rel) {
      case Relationship.none:
        return FilledButton.tonal(
          style: FilledButton.styleFrom(minimumSize: size),
          onPressed: f == null
              ? null
              : () => run(() => f.sendRequest(u), 'Đã gửi lời mời kết bạn'),
          child: const Text('Kết bạn'),
        );
      case Relationship.pendingOut:
        return TextButton(
          style: TextButton.styleFrom(
              minimumSize: size, foregroundColor: scheme.secondary),
          onPressed: () {
            final r = f?.outgoing.where((r) => r.user.userId == u.userId);
            if (r != null && r.isNotEmpty) {
              run(() => f!.cancelOutgoing(r.first), 'Đã hủy lời mời');
            }
          },
          child: const Text('Đã gửi · Hủy'),
        );
      case Relationship.pendingIn:
        return FilledButton.tonal(
          style: FilledButton.styleFrom(minimumSize: size),
          onPressed: () {
            final r = f?.incomingFrom(u.userId);
            if (r != null) {
              run(() => f!.accept(r), 'Đã kết bạn với ${u.username}');
            }
          },
          child: const Text('Chấp nhận'),
        );
      case Relationship.friends:
      case Relationship.self:
        return Semantics(
          label: 'Đã là bạn bè',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 18, color: scheme.secondary),
                const SizedBox(width: 4),
                Text('Bạn bè', style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ),
        );
    }
  }
}

/// Dùng cho điều hướng: chuyển [FriendsSegment] sang [SocialScreenState].
extension SocialScreenKey on GlobalKey<SocialScreenState> {
  void show(FriendsSegment s) => currentState?.showSegment(s);
}
