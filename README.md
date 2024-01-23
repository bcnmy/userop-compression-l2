# PoC for Calldata Compression on Layer 2 - Eg: Using Rage Trade's Transactions
![image](https://github.com/bcnmy/l2-calldata-compression-poc/assets/16562513/8a833d40-bd66-4e10-bb7a-8376fdca777d)


In Layer 2 (L2) blockchain ecosystems, optimizing calldata is more than just compression—it's about smart data reduction. Here's how we do it:

1. **Short IDs for Addresses**: Instead of using full-length addresses, we assign shorter IDs. This is effective because the active addresses are far fewer than all possible addresses. This is inspired from a PoC Vitalik did recently on dictionary based calldata reduction. https://github.com/ethereum/research/blob/master/rollup_compression/dicts.py
    
2. **Compaction Over Standard ABI Encoding**: Standard ABI encoding is inefficient, padding data to 32 bytes. We tackle this by packing data more densely and using a custom parser.
    
3. **Pattern Recognition with Custom Resolvers**: We analyze common data patterns and use custom resolvers to compress and decompress this data efficiently. This method also offloads repetitive data to on-chain storage. This effectively moves information about repetitive data and the "structure" away from the calldata into the resolver contract.
    
4. **Precision Reduction in Gas Limits**: Fields like gas limits, which can tolerate slight imprecision, are compressed by reducing their precision. Note this this is lossy compression, but this fine (with a certain range) for fields like callGasLimit and verificationGasLimit since unused gas is returned to the payer (atleast as of EPv0.6)

5. **Remove redundant information such as handleOps selector from calldata**: We simply send the calldata to the CompressionMiddleware's fallback function, which saves us 4 bytes of calldata per transaction.

### Application in the Provided Code

In the provided Solidity code:

### CompressionMiddleware Contract Compression Techniques

1. **Sender Address Compression**: 
    - Technique: Reduced Precision Representation.
    - Implementation: Compresses the sender address using only 3 bytes.
	
2. **Nonce Compression**:    
    - Technique: Reduced Precision Representation.
    - Implementation: Represents the nonce with 24 bytes instead of 32 bytes.
	
3. **Pre-Verification Gas Compression**:    
    - Technique: Reduced Precision Representation.
    - Implementation: Bounds the pre-verification gas to 26 bytes.
	
4. **Verification Gas Limit Compression**:    
    - Technique: Reduced Precision Representation with Approximation.
    - Implementation: Approximates to the nearest multiple of 5000, compressing it into 1 byte.
	
5. **Call Gas Limit Compression**:    
    - Technique: Reduced Precision Representation with Approximation.
    - Implementation: Approximates to the nearest multiple of 50000, compressing it into 1 byte.
	
6. **Max Priority Fee Per Gas Compression**:    
    - Technique: Reduced Precision Representation with Multiplier.
    - Implementation: Uses a multiplier of 0.01 gwei, compressing into 2 bytes.

7. **Max Fee Per Gas Compression**:    
    - Technique: Reduced Precision Representation with Multiplier.
    - Implementation: Uses a multiplier of 0.0001 gwei, compressing into 2 bytes.
	
8. **Calldata Compression**:    
    - Technique: Custom Encoding Format.
    - Implementation: Encodes with a resolver ID, length, and compressed data.

9. **PaymasterAndData Compression**:    
    - Technique: Custom Encoding Format.
    - Implementation: Uses a similar format to `calldata`.
	
10. **Signature Compression**: 
    - Technique: Custom Encoding Format.
    - Implementation: Compresses using a format that includes a resolver ID and length.

### Resolver-Specific Compression Techniques

1. **BatchedSessionRouterResolver (op.signature)**:    
    - Hardcoded Addresses: `batchedSessionRouter` and `sessionKeyManager`.
    - ID Replacement: 2-byte ID for `sessionValidationModule` using an on-chain dictionary.
    - Dynamic Data Compression: Compresses `SessionData` structure.
    - Assembly for Data Handling: Uses assembly for efficient data extraction.
	
2. **BiconomyVerifyingPaymasterResolver (op.paymasterAndData)**:    
    - Hardcoded Paymaster Address.
    - ID Replacement: 2-byte ID for `paymasterId` using an on-chain dictionary.
    - Efficient Signature Encoding: `<2 bytes - length><signature>` format.
	
3. **RageTradeSubmitDelayedOrderCalldataResolver (op.callData)** :    
    - Direct Encoding: Prepares calldata for delayed orders using `abi.encodeCall`.
	
These strategies collectively reduce the calldata size, leading to cost-efficient transactions on L2 blockchains.

# Setup
1. Git Clone
2. `forge test`

# Results
The UserOperation from the following transaction was chosen: https://optimistic.etherscan.io/tx/0x38a6f56d0a1190fc94b7d6a5e501873427b5dd4b4806e2718b7fa69b0bde5ccf.

This is transaction from RageTrade that utilizes:
1. Session Keys via the BatchedSessionRouter for the signing mechanism.
2. Verifying Singleton Paymaster for gas sponsorship. 
3. Interacts with the `PerpsV2MarketDelayedIntent` to submit an order.

## Scoring Function

**Theoretical**
```
function calldataCost(bytes memory data) internal pure returns (uint256 cost) {
	// 4 for 0 bytes and 16 for non zero bytes
	for (uint256 i = 0; i < data.length; i++) {
		if (uint8(data[i]) == 0) {
			cost += 4;
		} else {
			cost += 16;
		}
	}
}
```
Source: https://docs.optimism.io/stack/transactions/transaction-fees


**Mainnet**

Sent a transaction with the calldata to an EOA on Optimism Mainnet, so that calldata cost is incurred but no execution cost is incurred. Note that in the original transaction, 97% of the total gas cost is  contributed by the L1 Calldata Posting cost, therefore these transactions should be representative of actual transactions when it comes to gas.
## Original 
### Handle Ops Calldata
```
0x1fad948c000000000000000000000000000000000000000000000000000000000000004000000000000000000000000080213f829c8543eda6b1f0f303e94b8e504b53d8000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000002a757ab30726a7d839f5bdf2fd790b4cf2eadd5e0000000000000000000000000000000000000000001c3fa800000000000000000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000e7af700000000000000000000000000000000000000000000000000000000000249f00000000000000000000000000000000000000000000000000000000002e71e9f000000000000000000000000000000000000000000000000000000000098fe1e00000000000000000000000000000000000000000000000000000000000f4240000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000004c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c400004680000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000ea09d97b4084d859328ec4bf8ebcf9ecca26f1d0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000006485f05ab50000000000000000000000000000000000000000000000255f1898ded107e72c000000000000000000000000000000000000000000000003fe58dd566c1e36fc72616765000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011400000f79b7faf42eebadba19acc07cd08af4478900000000000000000000000006759c4726202f40275ed9267bbe5e5dc691c738000000000000000000000000000000000000000000000000000000006572c9a8000000000000000000000000000000000000000000000000000000006572c2a000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000041319e0110ef3d5983b757bd952662bdaaa4b2a9ae460509d09d3442c29e21e15064eaaf64c5fd44b1c858c69e971818dda495192f210ec6c07a245b0e86a0028b1b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000d09967410f8c76752a104c9848b57ebba5500000000000000000000000000000000000000000000000000000000000002e0000000000000000000000000000002fbffedd9b33f4e7156f2de8d48945e7489000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000002600000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000659a4e11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008be2d79c4cfe3d7fb660d9cc1991bfd0d4267e100000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000014aec3d80511d3758da3d4855f7649e01f48bb412e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000049b1b6f367a3afd8c538350ee36cf685179c2f62b0da2f7a5008546b815fc68e4068826b594a1849812e8c6f4753d9118d05255238162f09e4770efc7b98cf95215a890b22ab475cf7f46080839cedf61db2b261ab5db777ff1160aea9b8e917021a2d7f4510a201313c560c905e07de58937e5fbfc0875bab6a4a04db6f6f8af0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004103052d4fd3dff2d9c38d9e816856babb7f6d3f983d0542666d011484e8bee5d06ca95a7364cc1667afe5f03484d635069806dccb146bb5469b1cc570c30e30271b00000000000000000000000000000000000000000000000000000000000000
```
Theoretical Gas Cost: 15280.

Mainnet Cost: $0.34. https://optimistic.etherscan.io/tx/0x04755b9540d06649091b99ac6e61088e2b565b960587fd9b2d5035d95ec8df2c

### Compressed Calldata
```
0x0000000000000000000000000000000000000000000000001c3fa80000000000000000000000000000000000000000000002e71e9f1f130003e80000640000006485f05ab50000000000000000000000000000000000000000000000255f1898ded107e72c000000000000000000000000000000000000000000000003fe58dd566c1e36fc726167650000000000000000000000000000000000000000000000000000000000000051000000006572c9a800006572c2a00041319e0110ef3d5983b757bd952662bdaaa4b2a9ae460509d09d3442c29e21e15064eaaf64c5fd44b1c858c69e971818dda495192f210ec6c07a245b0e86a0028b1b000001c3018000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000e80000659a4e1100000000000000000014aec3d80511d3758da3d4855f7649e01f48bb412e00c0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000049b1b6f367a3afd8c538350ee36cf685179c2f62b0da2f7a5008546b815fc68e4068826b594a1849812e8c6f4753d9118d05255238162f09e4770efc7b98cf95215a890b22ab475cf7f46080839cedf61db2b261ab5db777ff1160aea9b8e917021a2d7f4510a201313c560c905e07de58937e5fbfc0875bab6a4a04db6f6f8af000000000000000000000000000000000000000000000000000003052d4fd3dff2d9c38d9e816856babb7f6d3f983d0542666d011484e8bee5d06ca95a7364cc1667afe5f03484d635069806dccb146bb5469b1cc570c30e30271b
```
Theoretical Gas Cost: 6924 **(54% reduction)**

Mainnet Cost: $0.18 **(47% reduction)**. https://optimistic.etherscan.io/tx/0xbd0429aea338f8da2cb44adf6b105cb76541d2098a52981d8796a5b623a76b34

The results indicate that the reduction in calldata with this algorithm translates very well to actual real life results.

### Notes
1. I can do a much better job of compressing the signature, however for the PoC purposes I've chosen to not complicate it too much. Notice that op.signature is quite large, and this is due to the fact that SessionKeys + BatchedSessionRouter is being used. Once SessionKeysV2 goes live, this cost will go down significantly since much of these techniques are natively incorporated into it's design given the heavy focus on callData reduction.
2. The solution is feasible if we encourage developers to identify patterns in their calldata structures and write appropriate resolvers to handle it. This opens us a new paradigm when it comes to Gas Optimisation and opens a path forward to another ERC for standardising Resolvers, Resolver Registries and Onchain Address Dictionaries.
