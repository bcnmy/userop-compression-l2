// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {console2} from "forge-std/Test.sol";
import {BaseTest} from "./BaseTest.sol";
import {EP6Decompressor, IEP6Decompressor} from "src/EP6Decompressor.sol";
import {IDecompressor} from "src/interfaces/IDecompressor.sol";
import {AddressRegistry} from "src/decompressor/AddressRegistry.sol";
import {RageTradeSubmitDelayedOrderCalldataDecompressor} from
    "src/decompressor/RageTradeSubmitDelayedOrderCalldataDecompressor.sol";
import {BatchedSessionRouterDecompressor} from "src/decompressor/BatchedSessionRouterDecompressor.sol";
import {BiconomyVerifyingPaymasterDecompressor} from "src/decompressor/BiconomyVerifyingPaymasterDecompressor.sol";
import {IEntryPoint, UserOperation} from "account-abstraction/interfaces/IEntryPoint.sol";

contract RageTradeCompresssionTest is BaseTest {
    EntryPointStub entryPointStub;
    EP6Decompressor epDecompressor;
    RageTradeSubmitDelayedOrderCalldataDecompressor rageTradeSubmitDelayedOrderCalldataDecompressor;
    BatchedSessionRouterDecompressor batchedSessionRouterDecompressor;
    BiconomyVerifyingPaymasterDecompressor biconomyVerifyingPaymasterDecompressor;

    struct SessionData {
        uint48 validUntil;
        uint48 validAfter;
        address sessionValidationModule;
        bytes sessionKeyData;
        bytes32[] merkleProof;
        bytes callSpecificData;
    }

    // https://optimistic.etherscan.io/tx/0x38a6f56d0a1190fc94b7d6a5e501873427b5dd4b4806e2718b7fa69b0bde5ccf/advanced
    bytes constant originalHandleOpsCalldata =
        hex"1fad948c000000000000000000000000000000000000000000000000000000000000004000000000000000000000000080213f829c8543eda6b1f0f303e94b8e504b53d8000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000002a757ab30726a7d839f5bdf2fd790b4cf2eadd5e0000000000000000000000000000000000000000001c3fa800000000000000000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000e7af700000000000000000000000000000000000000000000000000000000000249f00000000000000000000000000000000000000000000000000000000002e71e9f000000000000000000000000000000000000000000000000000000000098fe1e00000000000000000000000000000000000000000000000000000000000f4240000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000004c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c400004680000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000ea09d97b4084d859328ec4bf8ebcf9ecca26f1d0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000006485f05ab50000000000000000000000000000000000000000000000255f1898ded107e72c000000000000000000000000000000000000000000000003fe58dd566c1e36fc72616765000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011400000f79b7faf42eebadba19acc07cd08af4478900000000000000000000000006759c4726202f40275ed9267bbe5e5dc691c738000000000000000000000000000000000000000000000000000000006572c9a8000000000000000000000000000000000000000000000000000000006572c2a000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000041319e0110ef3d5983b757bd952662bdaaa4b2a9ae460509d09d3442c29e21e15064eaaf64c5fd44b1c858c69e971818dda495192f210ec6c07a245b0e86a0028b1b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000d09967410f8c76752a104c9848b57ebba5500000000000000000000000000000000000000000000000000000000000002e0000000000000000000000000000002fbffedd9b33f4e7156f2de8d48945e7489000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000002600000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000659a4e11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008be2d79c4cfe3d7fb660d9cc1991bfd0d4267e100000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000014aec3d80511d3758da3d4855f7649e01f48bb412e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000049b1b6f367a3afd8c538350ee36cf685179c2f62b0da2f7a5008546b815fc68e4068826b594a1849812e8c6f4753d9118d05255238162f09e4770efc7b98cf95215a890b22ab475cf7f46080839cedf61db2b261ab5db777ff1160aea9b8e917021a2d7f4510a201313c560c905e07de58937e5fbfc0875bab6a4a04db6f6f8af0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004103052d4fd3dff2d9c38d9e816856babb7f6d3f983d0542666d011484e8bee5d06ca95a7364cc1667afe5f03484d635069806dccb146bb5469b1cc570c30e30271b00000000000000000000000000000000000000000000000000000000000000";

    function setUp() public override {
        super.setUp();
        EP6Decompressor.EP6DecompressorConfiguration memory overrides;

        entryPointStub = new EntryPointStub();
        epDecompressor = new EP6Decompressor(IEntryPoint(address(entryPointStub)), overrides);
        rageTradeSubmitDelayedOrderCalldataDecompressor = new RageTradeSubmitDelayedOrderCalldataDecompressor();
        batchedSessionRouterDecompressor = new BatchedSessionRouterDecompressor();
        biconomyVerifyingPaymasterDecompressor = new BiconomyVerifyingPaymasterDecompressor();
    }

    function decodeHandleOpsData(bytes calldata data) public pure returns (UserOperation[] memory, address) {
        (UserOperation[] memory originalOps, address originalBeneficiary) =
            abi.decode(data[4:], (UserOperation[], address));

        return (originalOps, originalBeneficiary);
    }

    function _registerPmdDecompressor(UserOperation memory op) internal {
        bytes memory pmdWithoutPaymasterAddress = abi.encodePacked(op.paymasterAndData);
        assembly ("memory-safe") {
            let length := mload(pmdWithoutPaymasterAddress)

            pmdWithoutPaymasterAddress := add(pmdWithoutPaymasterAddress, 20)
            mstore(pmdWithoutPaymasterAddress, sub(length, 20))
        }

        (address paymasterId,,,) = abi.decode(pmdWithoutPaymasterAddress, (address, uint48, uint48, bytes));

        // Register paymasterId
        biconomyVerifyingPaymasterDecompressor.paymasterIdRegistry().register(paymasterId);
    }

    function _registerSigDecompressor(UserOperation memory op) internal {
        (bytes memory moduleSignature,) = abi.decode(op.signature, (bytes, address));
        (, SessionData[] memory sessionDatas,) = abi.decode(moduleSignature, (address, SessionData[], bytes));

        for (uint256 i = 0; i < sessionDatas.length; i++) {
            SessionData memory sessionData = sessionDatas[i];

            // register svm
            batchedSessionRouterDecompressor.svmRegistry().register(sessionData.sessionValidationModule);
        }
    }

    function testCompressionInitialRegistrationOp() external {
        (UserOperation[] memory ops, address originalBeneficiary) = this.decodeHandleOpsData(originalHandleOpsCalldata);

        UserOperation memory originalOp = ops[0];
        _registerPmdDecompressor(originalOp);
        _registerSigDecompressor(originalOp);

        // Adjust cgl,vgl,mfpg,mpfpg to be nearest multiple of corrspoding multipliers
        originalOp.callGasLimit = (originalOp.callGasLimit / epDecompressor.CALL_GAS_LIMIT_MULTIPLIER())
            * epDecompressor.CALL_GAS_LIMIT_MULTIPLIER();
        originalOp.verificationGasLimit = (
            originalOp.verificationGasLimit / epDecompressor.VERIFICATION_GAS_LIMIT_MULTIPLIER()
        ) * epDecompressor.VERIFICATION_GAS_LIMIT_MULTIPLIER();
        originalOp.maxFeePerGas = (originalOp.maxFeePerGas / epDecompressor.MAX_FEE_PER_GAS_MULTIPLIER())
            * epDecompressor.MAX_FEE_PER_GAS_MULTIPLIER();
        originalOp.maxPriorityFeePerGas = (
            originalOp.maxPriorityFeePerGas / epDecompressor.MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER()
        ) * epDecompressor.MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER();

        IEP6Decompressor.CompressionOptions memory options = IEP6Decompressor.CompressionOptions({
            paymasterAndDataDecompressor: biconomyVerifyingPaymasterDecompressor,
            signatureDecompressor: batchedSessionRouterDecompressor,
            initCodeDecompressor: IDecompressor(address(0)),
            callDataDecompressor: rageTradeSubmitDelayedOrderCalldataDecompressor
        });
        bytes memory compressedOp = epDecompressor.compressOps(toArray(originalOp), toArray(options));

        vm.prank(originalBeneficiary);
        (bool success,) = address(epDecompressor).call(compressedOp);
        assertTrue(success, "Call to epDecompressor failed");

        assertEq(entryPointStub.beneficiary(), originalBeneficiary, "Beneficiary mismatch");
        assertEq(entryPointStub.userOp().sender, originalOp.sender, "Sender mismatch");
        assertEq(entryPointStub.userOp().nonce, originalOp.nonce, "Nonce mismatch");
        assertEq(entryPointStub.userOp().preVerificationGas, originalOp.preVerificationGas, "PVG mismatch");
        assertApproxEqRel(
            entryPointStub.userOp().verificationGasLimit,
            originalOp.verificationGasLimit,
            5e16,
            "Verification gas limit mismatch"
        );
        assertApproxEqRel(
            entryPointStub.userOp().callGasLimit, originalOp.callGasLimit, 1e16, "Call gas limit mismatch"
        );
        assertApproxEqRel(
            entryPointStub.userOp().maxFeePerGas, originalOp.maxFeePerGas, 1e16, "Max fee per gas mismatch"
        );
        assertApproxEqRel(
            entryPointStub.userOp().maxPriorityFeePerGas,
            originalOp.maxPriorityFeePerGas,
            1e16,
            "Max priority fee per gas mismatch"
        );
        assertEq(entryPointStub.userOp().callData, originalOp.callData, "Call data mismatch");
        assertEq(entryPointStub.userOp().paymasterAndData, originalOp.paymasterAndData, "Paymaster and data mismatch");
        assertEq(entryPointStub.userOp().signature, originalOp.signature, "Signature mismatch");

        uint256 originalCalldataCost = calldataCost(originalHandleOpsCalldata);
        uint256 compressedCalldataCost = calldataCost(compressedOp);
        console2.log("Original calldata cost:", originalCalldataCost);
        console2.log("Compressed calldata cost:", compressedCalldataCost);
        uint256 reductionPercentage = (originalCalldataCost - compressedCalldataCost) * 100 / originalCalldataCost;
        console2.log("Reduction percentage:", reductionPercentage);
    }

    function testCompressionPostRegistration() external {
        (UserOperation[] memory ops, address originalBeneficiary) = this.decodeHandleOpsData(originalHandleOpsCalldata);

        UserOperation memory originalOp = ops[0];
        _registerPmdDecompressor(originalOp);
        _registerSigDecompressor(originalOp);

        // Adjust cgl,vgl,mfpg,mpfpg to be nearest multiple of corrspoding multipliers
        originalOp.callGasLimit = (originalOp.callGasLimit / epDecompressor.CALL_GAS_LIMIT_MULTIPLIER())
            * epDecompressor.CALL_GAS_LIMIT_MULTIPLIER();
        originalOp.verificationGasLimit = (
            originalOp.verificationGasLimit / epDecompressor.VERIFICATION_GAS_LIMIT_MULTIPLIER()
        ) * epDecompressor.VERIFICATION_GAS_LIMIT_MULTIPLIER();
        originalOp.maxFeePerGas = (originalOp.maxFeePerGas / epDecompressor.MAX_FEE_PER_GAS_MULTIPLIER())
            * epDecompressor.MAX_FEE_PER_GAS_MULTIPLIER();
        originalOp.maxPriorityFeePerGas = (
            originalOp.maxPriorityFeePerGas / epDecompressor.MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER()
        ) * epDecompressor.MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER();

        IEP6Decompressor.CompressionOptions memory options = IEP6Decompressor.CompressionOptions({
            paymasterAndDataDecompressor: biconomyVerifyingPaymasterDecompressor,
            signatureDecompressor: batchedSessionRouterDecompressor,
            initCodeDecompressor: IDecompressor(address(0)),
            callDataDecompressor: rageTradeSubmitDelayedOrderCalldataDecompressor
        });
        bytes memory compressedOp = epDecompressor.compressOps(toArray(originalOp), toArray(options));

        vm.prank(originalBeneficiary);
        (bool success,) = address(epDecompressor).call(compressedOp);
        assertTrue(success, "Call to epDecompressor failed");

        compressedOp = epDecompressor.compressOps(toArray(originalOp), toArray(options));
        vm.prank(originalBeneficiary);
        (success,) = address(epDecompressor).call(compressedOp);
        assertTrue(success, "2nd Call to epDecompressor failed");

        assertEq(entryPointStub.beneficiary(), originalBeneficiary, "Beneficiary mismatch");
        assertEq(entryPointStub.userOp().sender, originalOp.sender, "Sender mismatch");
        assertEq(entryPointStub.userOp().nonce, originalOp.nonce, "Nonce mismatch");
        assertEq(entryPointStub.userOp().preVerificationGas, originalOp.preVerificationGas, "PVG mismatch");
        assertApproxEqRel(
            entryPointStub.userOp().verificationGasLimit,
            originalOp.verificationGasLimit,
            5e16,
            "Verification gas limit mismatch"
        );
        assertApproxEqRel(
            entryPointStub.userOp().callGasLimit, originalOp.callGasLimit, 1e16, "Call gas limit mismatch"
        );
        assertApproxEqRel(
            entryPointStub.userOp().maxFeePerGas, originalOp.maxFeePerGas, 1e16, "Max fee per gas mismatch"
        );
        assertApproxEqRel(
            entryPointStub.userOp().maxPriorityFeePerGas,
            originalOp.maxPriorityFeePerGas,
            1e16,
            "Max priority fee per gas mismatch"
        );
        assertEq(entryPointStub.userOp().callData, originalOp.callData, "Call data mismatch");
        assertEq(entryPointStub.userOp().paymasterAndData, originalOp.paymasterAndData, "Paymaster and data mismatch");
        assertEq(entryPointStub.userOp().signature, originalOp.signature, "Signature mismatch");

        uint256 originalCalldataCost = calldataCost(originalHandleOpsCalldata);
        uint256 compressedCalldataCost = calldataCost(compressedOp);
        console2.log("Original calldata cost:", originalCalldataCost);
        console2.log("Compressed calldata cost:", compressedCalldataCost);
        uint256 reductionPercentage = (originalCalldataCost - compressedCalldataCost) * 100 / originalCalldataCost;
        console2.log("Reduction percentage:", reductionPercentage);
    }

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
}

contract EntryPointStub {
    address public beneficiary;
    UserOperation private _userOp;

    function handleOps(UserOperation[] calldata ops, address payable _beneficiary) external {
        beneficiary = _beneficiary;
        _userOp = ops[0];
    }

    function getNonce(address, uint192 key) external pure returns (uint256) {
        return 0 | (uint256(key) << 64);
    }

    function userOp() external view returns (UserOperation memory) {
        return _userOp;
    }
}
