import 'dart:convert';
import 'package:http/http.dart' as http;

class StarknetService {
  final String publicRpcUrl = "https://starknet-sepolia.infura.io/v3/d04233b670d4486cb34545d9049505d5";
  
  // The scalable Whitelist
  final Map<String, Map<String, dynamic>> supportedTokens = {
    'STRK': {
      'address': '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d',
      'decimals': 18,
    },
    'ETH': {
      'address': '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7',
      'decimals': 18,
    },
    'USDC': { 
      'address': '0x0512feac6339ff7889822cb5aa2a86c848e9d392bb0e3e237c008674feed8343',
      'decimals': 6,
    },
    'USDT': { 
      'address': '0x02ab8758891e84b968ff11361789070c6b1af2df618d6d2f4a78b0757573c6eb',
      'decimals': 6,
    },
    'WBTC': { 
      'address': '0x0496bef3ed20371382fBe0CA6A5a64252c5c848F9f1F0ccCF8110Fc4def912d5',
      'decimals': 8,
    },
  };

  // --- NEW PUBLIC METHODS ---
  
  /// Returns the contract address for a given symbol (e.g., 'USDC'). 
  /// Returns null if token is not found.
  String? getTokenAddress(String symbol) {
    return supportedTokens[symbol]?['address'] as String?;
  }

  /// Returns decimals for a token. Defaults to 18 if not found.
  int getTokenDecimals(String symbol) {
    return supportedTokens[symbol]?['decimals'] as int? ?? 18;
  }

  // --------------------------

  Future<Map<String, double>> getTokenBalances(String userAddress) async {
    print('[DEBUG] Initiating concurrent balance fetch for multiple tokens...');
    Map<String, double> results = {};
    
    // Map the token keys to a list of asynchronous futures
    List<Future<void>> fetchTasks = supportedTokens.keys.map((symbol) async {
      final tokenData = supportedTokens[symbol]!;
      final balance = await _fetchSingleToken(
        tokenData['address'], 
        userAddress, 
        tokenData['decimals'], 
        symbol
      );
      results[symbol] = balance;
    }).toList();

    // Execute all network requests simultaneously
    await Future.wait(fetchTasks);
    
    print('[DEBUG] Concurrent fetch complete. Results: $results');
    return results;
  }

  // The missing method: Fetches a single token and parses its decimals
  Future<double> _fetchSingleToken(String tokenAddress, String userAddress, int decimals, String symbol) async {
    try {
      const String selectorBalanceOf = "0x02e4263afad30923c891518314c3c95dbe830a16874e8abc5777a9a20b54c76e";
      
      final requestBody = {
        "jsonrpc": "2.0",
        "method": "starknet_call",
        "params": [
          {
            "contract_address": tokenAddress,
            "entry_point_selector": selectorBalanceOf,
            "calldata": [userAddress]
          },
          "latest"
        ],
        "id": 1
      };
      
      final response = await http.post(
        Uri.parse(publicRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      // THE FIX: If the blockchain returns an error (e.g., Contract Not Found), 
      // just return 0.0 gracefully instead of crashing the entire batch!
      if (data.containsKey('error')) {
        print('[DEBUG] RPC Error fetching $symbol: ${data['error']['message']}. Defaulting to 0.0');
        return 0.0; 
      }
      
      final result = data['result'];
      if (result is List && result.isNotEmpty) {
        final hexString = result[0] as String;
        final rawBalance = BigInt.parse(hexString.replaceFirst('0x', ''), radix: 16);
        
        final divisor = BigInt.from(10).pow(decimals);
        return rawBalance / divisor;
      }
      return 0.0;
      
    } catch (e) {
      // This will now ONLY trigger if the device physically loses internet connection
      print("[DEBUG] Fatal Network Exception getting $symbol balance: $e");
      throw Exception("Network Failure");
    }
  }
}