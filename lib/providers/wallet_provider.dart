import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert'; // REQUIRED for jsonEncode
import 'dart:math'; // REQUIRED for decimal calculations
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:walletconnect_modal_flutter/services/explorer/i_explorer_service.dart';
import 'package:walletconnect_modal_flutter/walletconnect_modal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import '../services/starknet_service.dart';
import '../config/routes.dart';
import '../config/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletProvider with ChangeNotifier {
  late WalletConnectModalService _modalService;
  bool _isConnected = false;
  String? _userAddress;
  bool _isLoading = false;
  bool _hasNetworkError = false;
  bool get hasNetworkError => _hasNetworkError;
  final StarknetService _starknetService = StarknetService();
  Map<String, double> _tokenBalances = {
    'STRK': 0.0, 
    'ETH': 0.0, 
    'USDC': 0.0, 
    'USDT': 0.0,
    'WBTC': 0.0
  };
  StreamSubscription<Uri?>? _linkSubscription;
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<NavigatorState> _navigatorKey;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  // Change this to your actual dApp domain
  final String targetDomain = "lifelinereadyconnect.web.app"; 
  // Web app URL for wallet connection
  final String webAppUrl = "https://lifelinereadyconnect.web.app";

  bool get isConnected => _isConnected;
  String? get userAddress => _userAddress;
  String _network = "Sepolia Testnet"; // Default fallback
  String get network => _network;
  bool get isLoading => _isLoading;
  Map<String, double> get tokenBalances => _tokenBalances;
  GlobalKey<ScaffoldMessengerState> get scaffoldKey => _scaffoldKey;

  WalletProvider({
    required GlobalKey<NavigatorState> navigatorKey,
  }) : _navigatorKey = navigatorKey {
    _initDeepLinkHandler();
    init(); // Initialize WalletConnect
  }

  void _initDeepLinkHandler() {
    // Handle incoming links when the app is opened from a link
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri.toString());
      }
    }, onError: (err) {
      debugPrint("Deep link error: $err");
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> init() async {
    _modalService = WalletConnectModalService(
      projectId: AppConstants.reownProjectId,
      metadata: const PairingMetadata(
        name: 'LifeLine Protocol',
        description: 'Digital Inheritance Protocol',
        url: 'https://lifeline.app',
        icons: ['https://zappythedev.web.app/assets/images/zappythedev.png'],
      ),
      recommendedWalletIds: const {
        'bc949c5d968ae81310268bf9193f9c9fb7bb4e1283e1284af8f2bd4992535fd6', // Ready / Argent
      },
      excludedWalletState: ExcludedWalletState.all,
      optionalNamespaces: {
        'starknet': const RequiredNamespace(
          chains: ['starknet:SNSEPOLIA'],
          methods: [
            'starknet_signTypedData',
            'starknet_requestAddInvokeTransaction',
            'starknet_account'
          ],
          events: ['accountsChanged', 'chainChanged'], 
        )
      },
    );

    await _modalService.init();

    if (_modalService.isConnected) {
      _extractAddressFromSession(_modalService.session!);
    }
  }

  Future<void> restoreSession() async {
    print('[DEBUG] Checking SharedPreferences for saved wallet session...');
    final prefs = await SharedPreferences.getInstance();
    final savedAddress = prefs.getString('user_wallet_address');

    if (savedAddress != null && savedAddress.isNotEmpty) {
      print('[DEBUG] Found saved address: $savedAddress. Restoring session...');
      _userAddress = savedAddress;
      _isConnected = true;
      _isLoading = true; // Turn on the loading state
      notifyListeners(); // Instantly jump to dashboard

      print('[DEBUG] Fetching fresh token balances from Starknet...');
      await _getBalances();
      
      _isLoading = false; // Turn off loading state
      notifyListeners(); // CRITICAL: Tell the UI the balances have arrived!
      print('[DEBUG] Balances updated and UI refreshed.');
    } else {
      print('[DEBUG] No saved session found.');
    }
  }

  // --- STANDARD MODAL FLOW (For Argent) ---
  Future<void> connect(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _modalService.open(context: context);
      if (_modalService.isConnected) {
        _extractAddressFromSession(_modalService.session!);
      }
    } catch (e) {
      debugPrint("Modal Connect Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- HELPER: LAUNCH BRAAVOS OR FALLBACK TO STORE ---
  Future<bool> _launchBraavosDeepLink(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) {
        return true;
      }
    } catch (e) {
      debugPrint("[DEBUG] Launch Exception: $e");
    }
    
    // FALLBACK: Braavos not installed or unable to launch
    debugPrint("[DEBUG] Braavos not found. Redirecting to download page...");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("Braavos not found. Redirecting to App Store..."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        )
      );
    });
    
    final storeUri = Uri.parse('https://braavos.app/download-braavos-wallet/');
    try {
      await launchUrl(storeUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Failed to launch store URL: $e");
    }
    
    return false;
  }

  // --- BRAAVOS DIRECT FLOW (FIREBASE BRIDGE) ---
  Future<void> connectBraavosNatively() async {
    debugPrint("[DEBUG] BRAAVOS: Attempting Firebase Bridge connection...");
    
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Generate a unique session ID for this specific login attempt
      final String sessionId = "session_${DateTime.now().millisecondsSinceEpoch}";
      
      // 2. Start listening to the Firebase database BEFORE launching the web app
      StreamSubscription<DocumentSnapshot>? firestoreSubscription;
      
      firestoreSubscription = FirebaseFirestore.instance
          .collection('wallet_sessions')
          .doc(sessionId)
          .snapshots()
          .listen((snapshot) {
            
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'];
          
          if (status == 'connected') {
            final address = data['address'];
            if (address != null) {
              debugPrint("[DEBUG] Firebase Bridge Success! Address: $address");
              firestoreSubscription?.cancel(); // Stop listening to save resources
              _handleWalletConnection(address); // Passes data to your existing handler
            }
          } else if (status == 'error') {
            final message = data['message'] ?? "Unknown error";
            debugPrint("[DEBUG] Firebase Bridge Error: $message");
            firestoreSubscription?.cancel(); 
            _handleConnectionError("Connection rejected: $message");
          }
        }
      });

      // 3. Implement a 3-minute timeout to prevent infinite listening
      // If the user closes Braavos without connecting, this cleans up the state.
      Future.delayed(const Duration(minutes: 3), () {
        if (_isLoading) { 
          firestoreSubscription?.cancel();
          _handleConnectionError("Connection timed out. Please try again.");
        }
      });

      // 4. Launch Braavos externally (WITH GRACEFUL FALLBACK)
      final String url = 'braavos://dapp/$webAppUrl?session=$sessionId';
      final success = await _launchBraavosDeepLink(url);
      
      if (!success) {
        firestoreSubscription?.cancel();
        // Disable loading state without showing double-errors
        _isLoading = false;
        notifyListeners();
      }

    } catch (e) {
      debugPrint("Braavos Firebase Bridge Error: $e");
      _handleConnectionError("Braavos connection failed: $e");
    }
  }

  void _extractAddressFromSession(SessionData session) {
    final namespace = session.namespaces['starknet'];
    if (namespace != null && namespace.accounts.isNotEmpty) {
      
      // The CAIP-2 format is namespace:chainId:address (e.g. starknet:SN_SEPOLIA:0x123...)
      final accountData = namespace.accounts.first.split(':');
      if (accountData.length >= 3) {
        final chainId = accountData[1];
        // Dynamically set the network based on the wallet's response
        _network = chainId.contains('MAIN') ? 'Starknet Mainnet' : 'Sepolia Testnet';
        _userAddress = accountData[2];
      } else {
        _userAddress = accountData.last; // Fallback
      }
      
      _isConnected = true;
      _getBalances();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentRoute = ModalRoute.of(_navigatorKey.currentContext!)?.settings.name;
        if (currentRoute == AppRoutes.connectWallet) {
          _navigatorKey.currentState!.pushReplacementNamed(AppRoutes.dashboard);
        }
      });
      
      notifyListeners();
    }
  }

  // Manually triggered by the Pull-to-Refresh UI
  Future<void> refreshBalances() async {
    if (!isConnected || userAddress == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    await _getBalances();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _getBalances() async {
    try {
      _hasNetworkError = false; // Reset error state before trying
      _tokenBalances = await _starknetService.getTokenBalances(_userAddress!);
    } catch (e) {
      debugPrint("Error fetching token balances: $e");
      _hasNetworkError = true; // Flag the network failure
      // Keep whatever the last known balances were (or 0.0) instead of crashing
    }
  }

  void _handleDeepLink(String url) {
    final uri = Uri.parse(url);
    if (uri.scheme != 'lifeline') return;
    
    final action = uri.queryParameters['action'];
    final status = uri.queryParameters['status'];
    
    if (uri.path == '/wallet/connect' && status == 'connected') {
      final address = uri.queryParameters['address'];
      if (address != null) {
        _handleWalletConnection(address);
      }
    } else if (status == 'error') {
      final message = uri.queryParameters['message'] ?? "Unknown error";
      _handleConnectionError("Connection error: $message");
    }
  }

  Future<void> _handleWalletConnection(String address) async {
    _userAddress = address;
    _isConnected = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_wallet_address', address);
    print('[DEBUG] Wallet address written to SharedPreferences.');
    
    // Get token balances
    try {
      _tokenBalances = await _starknetService.getTokenBalances(address);
    } catch (e) {
      debugPrint("Error fetching token balances: $e");
      _tokenBalances = {'STRK': 0.0, 'USDC': 0.0};
    }
    
    _isLoading = false;
    notifyListeners();
    
    // If coming from connect screen, navigate to dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentRoute = ModalRoute.of(_navigatorKey.currentContext!)?.settings.name;
      if (currentRoute == AppRoutes.connectWallet) {
        _navigatorKey.currentState!.pushReplacementNamed(AppRoutes.dashboard);
      }
    });
  }

  void _handleConnectionError(String error) {
    debugPrint("Wallet connection error: $error");
    _isLoading = false;
    notifyListeners();
    
    // Show error to user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.showSnackBar(
        SnackBar(content: Text("Wallet connection failed: $error"))
      );
    });
  }

  Future<void> disconnect() async {
    try {
      await _modalService.disconnect();
    } catch (e) {
      debugPrint("Disconnect Error: $e");
    }
    // ADD THIS TO WIPE THE SESSION
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_wallet_address');
    print('[DEBUG] Wiped wallet address from SharedPreferences.');

    _userAddress = null;
   _tokenBalances = {
    'STRK': 0.0, 
    'ETH': 0.0, 
    'USDC': 0.0, 
    'USDT': 0.0, // ADDED
    'WBTC': 0.0
  };
    _isConnected = false;
    notifyListeners();
    
    // Navigate back to connect screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState!.pushReplacementNamed(AppRoutes.connectWallet);
    });
  }

  // --- HELPER: Detect Token Decimals ---
  // Returns 6 for USDC/USDT addresses, 18 for others.
  int _getDecimals(String tokenAddress) {
    final addr = tokenAddress.toLowerCase();
    // Known Starknet Sepolia & Mainnet addresses for USDC/USDT
    if (addr.contains("053b40a6") || // USDC Sepolia
        addr.contains("053c9125") || // USDT Sepolia or Mainnet USDC
        addr.contains("068f5c6a") || 
        addr.contains("feed8343") ||// USDC Sepolia
        addr.contains("512feac6")) { // The specific address from your error log
      return 6;
    }
    return 18; // Default for ETH, STRK
  }

  // --- SEND CREATE VAULT TRANSACTION (FIREBASE BRIDGE) ---
  Future<bool> sendCreateVaultTransaction({
    required String tokenAddress,
    required String heirAddress, 
    required String heirPubKey,  
    required double tokenAmount, 
    required int inactivityDurationSeconds,
  }) async {
    print('[DEBUG] === Preparing Multi-Call (Approve + Create) ===');

    if (!isConnected || userAddress == null) return false;

    try {
      final contractAddress = dotenv.env['LIFELINE_CONTRACT_ADDRESS'];
      if (contractAddress == null) throw Exception("Contract missing from .env");

      // 1. DECIMAL FIX: Auto-detect decimals based on token address
      int decimals = _getDecimals(tokenAddress);
      print('[DEBUG] Detected decimals for $tokenAddress: $decimals');

      // 2. Prepare Amount (u256 split for Cairo)
      final amountBigInt = BigInt.from(tokenAmount * pow(10, decimals));
      
      // Split into low and high 128-bit parts
      final u256Low = (amountBigInt & BigInt.parse('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF')).toString();
      final u256High = (amountBigInt >> 128).toString();

      // 3. CONSTRUCT MULTI-CALL PAYLOAD
      // Call 1: Approve the LifeLine contract to spend tokens
      final Map<String, dynamic> callApprove = {
        'contractAddress': tokenAddress,
        'entrypoint': 'approve',
        'calldata': [contractAddress, '0x${BigInt.parse(u256Low).toRadixString(16)}', '0x${BigInt.parse(u256High).toRadixString(16)}'] // Spender, Low, High
      };

      // Call 2: Create the Vault
      final Map<String, dynamic> callCreate = {
        'contractAddress': contractAddress,
        'entrypoint': 'create_vault',
        'calldata': [
          tokenAddress,
          heirAddress == "0x0" ? "0x0" : heirAddress,
          heirPubKey == "0x0" ? "0x0" : heirPubKey,
          '0x${BigInt.parse(u256Low).toRadixString(16)}',
          '0x${BigInt.parse(u256High).toRadixString(16)}',
          '0x${inactivityDurationSeconds.toRadixString(16)}'
        ]
      };

      // Combine into a list
      final List<Map<String, dynamic>> transactions = [callApprove, callCreate];
      
      // JSON Encode the list for the URL
      final encodedTransactions = Uri.encodeComponent(jsonEncode(transactions));
      
      // 4. Generate unique Transaction Session ID
      final String txSessionId = "tx_${DateTime.now().millisecondsSinceEpoch}";
      print('[DEBUG] Generated TX Session ID: $txSessionId');

      // 5. Start listening to Firebase BEFORE launching Braavos
      Completer<bool> txCompleter = Completer<bool>();
      StreamSubscription<DocumentSnapshot>? firestoreSubscription;
      
      firestoreSubscription = FirebaseFirestore.instance
          .collection('transaction_sessions')
          .doc(txSessionId)
          .snapshots()
          .listen((snapshot) {
            
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'];
          
          if (status == 'success') {
            print("[DEBUG] Firebase Bridge TX Success! Hash: ${data['hash']}");
            firestoreSubscription?.cancel();
            if (!txCompleter.isCompleted) txCompleter.complete(true);
          } else if (status == 'error') {
            print("[DEBUG] Firebase Bridge TX Error: ${data['message']}");
            firestoreSubscription?.cancel();
            if (!txCompleter.isCompleted) txCompleter.complete(false);
          }
        }
      });

      // 6. Setup 5-minute timeout
      Future.delayed(const Duration(minutes: 5), () {
        if (!txCompleter.isCompleted) {
          print('[DEBUG] TX Session timed out.');
          firestoreSubscription?.cancel();
          txCompleter.complete(false);
        }
      });

      // 7. Launch Braavos with gracefully falling back if absent
      final String url = 'braavos://dapp/$webAppUrl?action=transaction&'
          'txSessionId=$txSessionId&'
          'contractAddress=$contractAddress&' // Used for Event Parsing in WebConnector
          'transactions=$encodedTransactions'; // The Multi-Call Payload
      
      final success = await _launchBraavosDeepLink(url);
      
      if (success) {
        return await txCompleter.future;
      } else {
        print('[DEBUG] ERROR: Could not launch Braavos');
        firestoreSubscription?.cancel();
        return false;
      }

    } catch (e) {
      print('[DEBUG] CRITICAL ERROR sending create_vault transaction: $e');
      return false;
    }
  }

  // --- PING VAULT (Fixed: Forces .env Contract Address & Multi-Call) ---
  Future<void> pingVault({
    required String vaultContractAddress, // Keeping param to not break HomeScreen, but we will ignore it.
    required String vaultId,
    required Function(bool) onResult,
    required BuildContext context,
  }) async {
    if (!isConnected || userAddress == null) {
      onResult(false);
      return;
    }
    
    _isLoading = true;
    notifyListeners();

    try {
      final realContractAddress = dotenv.env['LIFELINE_CONTRACT_ADDRESS'];
      if (realContractAddress == null) throw Exception("Contract missing from .env");

      final String txSessionId = "ping_${DateTime.now().millisecondsSinceEpoch}";
      
      // 1. Construct Transaction List
      final Map<String, dynamic> callPing = {
        'contractAddress': realContractAddress, // Using the forced correct address
        'entrypoint': 'ping_vault',
        'calldata': [vaultId]
      };
      
      final List<Map<String, dynamic>> transactions = [callPing];
      final encodedTransactions = Uri.encodeComponent(jsonEncode(transactions));

      StreamSubscription<DocumentSnapshot>? firestoreSubscription;
      bool isWaitingForTransaction = true;
      
      firestoreSubscription = FirebaseFirestore.instance
          .collection('transaction_sessions')
          .doc(txSessionId)
          .snapshots()
          .listen((snapshot) {
            
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'];
          
          if (status == 'success') {
            onResult(true);
            firestoreSubscription?.cancel();
            isWaitingForTransaction = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _isLoading = false;
              notifyListeners();
            });
          } else if (status == 'error') {
            _handleConnectionError(data['message'] ?? "Ping rejected by user.");
            onResult(false);
            firestoreSubscription?.cancel();
            isWaitingForTransaction = false;
          }
        }
      });

      // Timeout
      Future.delayed(const Duration(minutes: 5), () {
        if (isWaitingForTransaction) {
          firestoreSubscription?.cancel();
          isWaitingForTransaction = false;
          onResult(false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _isLoading = false;
            notifyListeners();
            _scaffoldKey.currentState?.showSnackBar(
              const SnackBar(content: Text("Transaction timed out. Please try again."))
            );
          });
        }
      });

      // 2. Launch Braavos securely
      final String url = 'braavos://dapp/$webAppUrl?action=transaction&'
          'txSessionId=$txSessionId&'
          'contractAddress=$realContractAddress&' 
          'transactions=$encodedTransactions'; 
      
      final success = await _launchBraavosDeepLink(url);
      
      if (!success) {
        firestoreSubscription?.cancel();
        isWaitingForTransaction = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isLoading = false;
          notifyListeners();
        });
        onResult(false);
      }
    } catch (e) {
      _handleConnectionError("Transaction failed: $e");
      onResult(false);
    }
  }

  // ==========================================================
  //  NEW METHODS: ADDED BELOW WITHOUT TOUCHING CODE ABOVE
  // ==========================================================

  // 1. ADD FUNDS (Approve + AddFunds Multi-Call)
  Future<bool> addFundsToVault({
    required String vaultId, // On-Chain ID (u64)
    required String tokenAddress,
    required double amount,
  }) async {
    if (!isConnected || userAddress == null) return false;

    try {
      final contractAddress = dotenv.env['LIFELINE_CONTRACT_ADDRESS'];
      if (contractAddress == null) throw Exception("Contract missing from .env");

      // 1. DECIMAL FIX
      int decimals = _getDecimals(tokenAddress);
      
      // Amount Logic (u256 split)
      final amountBigInt = BigInt.from(amount * pow(10, decimals)); 
      final u256Low = (amountBigInt & BigInt.parse('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF')).toString();
      final u256High = (amountBigInt >> 128).toString();

      // Call 1: Approve
      final Map<String, dynamic> callApprove = {
        'contractAddress': tokenAddress,
        'entrypoint': 'approve',
        'calldata': [contractAddress, '0x${BigInt.parse(u256Low).toRadixString(16)}', '0x${BigInt.parse(u256High).toRadixString(16)}']
      };

      // Call 2: Add Funds
      final Map<String, dynamic> callAddFunds = {
        'contractAddress': contractAddress,
        'entrypoint': 'add_funds',
        'calldata': [
          vaultId, // u64 Vault ID
          '0x${BigInt.parse(u256Low).toRadixString(16)}', 
          '0x${BigInt.parse(u256High).toRadixString(16)}'
        ]
      };

      final List<Map<String, dynamic>> transactions = [callApprove, callAddFunds];
      final encodedTransactions = Uri.encodeComponent(jsonEncode(transactions));
      final String txSessionId = "fund_${DateTime.now().millisecondsSinceEpoch}";

      return await _executeBraavosTransaction(
        txSessionId: txSessionId,
        urlParams: 'action=transaction&txSessionId=$txSessionId&contractAddress=$contractAddress&transactions=$encodedTransactions'
      );

    } catch (e) {
      print('[ERROR] Add Funds Failed: $e');
      return false;
    }
  }

  // 2. WITHDRAW FUNDS (Single Call)
  Future<bool> withdrawFromVault({
    required String vaultId,
    required double amount,
    String? tokenAddress, // OPTIONAL: Pass if you want precise decimals for USDC
  }) async {
    if (!isConnected || userAddress == null) return false;

    try {
      final contractAddress = dotenv.env['LIFELINE_CONTRACT_ADDRESS'];
      if (contractAddress == null) throw Exception("Contract missing from .env");
      
      // 1. DECIMAL FIX
      int decimals = 18; // Default
      if (tokenAddress != null) {
         decimals = _getDecimals(tokenAddress);
      }

      final amountBigInt = BigInt.from(amount * pow(10, decimals));
      final u256Low = (amountBigInt & BigInt.parse('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF')).toString();
      final u256High = (amountBigInt >> 128).toString();

      // Simple array for single call calldata: [vault_id, low, high]
      final List<String> calldata = [
        vaultId,
        '0x${BigInt.parse(u256Low).toRadixString(16)}',
        '0x${BigInt.parse(u256High).toRadixString(16)}'
      ];
      final encodedCalldata = Uri.encodeComponent(jsonEncode(calldata));
      final String txSessionId = "withdraw_${DateTime.now().millisecondsSinceEpoch}";

      return await _executeBraavosTransaction(
        txSessionId: txSessionId,
        urlParams: 'action=transaction&txSessionId=$txSessionId&contractAddress=$contractAddress&entryPoint=withdraw_funds&calldata=$encodedCalldata'
      );
    } catch (e) {
      print('[ERROR] Withdraw Failed: $e');
      return false;
    }
  }

  // 3. CANCEL VAULT (Single Call)
  Future<bool> cancelVault(String vaultId) async {
    if (!isConnected || userAddress == null) return false;

    try {
      final contractAddress = dotenv.env['LIFELINE_CONTRACT_ADDRESS'];
      if (contractAddress == null) throw Exception("Contract missing from .env");

      final List<String> calldata = [vaultId];
      final encodedCalldata = Uri.encodeComponent(jsonEncode(calldata));
      final String txSessionId = "cancel_${DateTime.now().millisecondsSinceEpoch}";

      return await _executeBraavosTransaction(
        txSessionId: txSessionId,
        urlParams: 'action=transaction&txSessionId=$txSessionId&contractAddress=$contractAddress&entryPoint=cancel_vault&calldata=$encodedCalldata'
      );
    } catch (e) {
      print('[ERROR] Cancel Failed: $e');
      return false;
    }
  }

  // --- HELPER: GENERIC TRANSACTION EXECUTOR (ONLY FOR NEW METHODS) ---
  Future<bool> _executeBraavosTransaction({required String txSessionId, required String urlParams}) async {
    Completer<bool> txCompleter = Completer<bool>();
    StreamSubscription<DocumentSnapshot>? firestoreSubscription;
    
    // Listen to Firebase
    firestoreSubscription = FirebaseFirestore.instance
        .collection('transaction_sessions')
        .doc(txSessionId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'];
        if (status == 'success') {
          firestoreSubscription?.cancel();
          if (!txCompleter.isCompleted) txCompleter.complete(true);
        } else if (status == 'error') {
          _handleConnectionError(data['message'] ?? "Transaction Failed");
          firestoreSubscription?.cancel();
          if (!txCompleter.isCompleted) txCompleter.complete(false);
        }
      }
    });

    // Timeout
    Future.delayed(const Duration(minutes: 5), () {
      if (!txCompleter.isCompleted) {
        firestoreSubscription?.cancel();
        txCompleter.complete(false);
      }
    });

    // Launch URL
    final String url = 'braavos://dapp/$webAppUrl?$urlParams';
    final success = await _launchBraavosDeepLink(url);
    
    if (success) {
      return await txCompleter.future;
    } else {
      firestoreSubscription?.cancel();
      return false;
    }
  }
}