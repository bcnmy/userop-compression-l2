// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseTest} from "./BaseTest.sol";
import {EP6Decompressor, IEP6Decompressor} from "src/EP6Decompressor.sol";
import {IDecompressor} from "src/interfaces/IDecompressor.sol";
import {IEntryPoint, UserOperation} from "account-abstraction/interfaces/IEntryPoint.sol";
import {RegistryLib} from "src/lib/RegistryLib.sol";
import {BytesLib} from "solidity-bytes-utils/BytesLib.sol";
import {UserOperation} from "account-abstraction/interfaces/IEntryPoint.sol";

contract EP6DecompressorTest is BaseTest {
    using BytesLib for bytes;

    EP6DecompressorWrapper private decompressor;
    EntryPointStub private entryPointV6;

    IDecompressor private calldataCompressor;
    IDecompressor private signatureCompressor;
    IDecompressor private initcodeCompressor;
    IDecompressor private paymasterAndDataCompressor;

    function setUp() public override {
        super.setUp();

        IEP6Decompressor.EP6DecompressorConfiguration memory config;

        entryPointV6 = new EntryPointStub();
        decompressor = new EP6DecompressorWrapper(IEntryPoint(address(entryPointV6)), config);
        calldataCompressor = new Decompressor();
        signatureCompressor = new Decompressor();
        initcodeCompressor = new Decompressor();
        paymasterAndDataCompressor = new Decompressor();
    }

    function testSenderCompression(address _s) public {
        vm.assume(_s != address(0));

        // Pre-Registration
        bytes memory compressed = decompressor.compressSender(_s);

        vm.expectEmit();
        emit RegistryLib.Registered(RegistryLib.FIRST_ID, _s, 0);
        assertEq(decompressor.decompressSender(compressed), _s);

        // Post Registration
        bytes memory postRegistrationCompressed = decompressor.compressSender(_s);
        assertEq(decompressor.decompressSender(postRegistrationCompressed), _s);
        assertTrue(postRegistrationCompressed.length < compressed.length);

        // Pre-Registration compressed should still be valid
        vm.expectEmit();
        emit RegistryLib.AlreadyRegistered(RegistryLib.FIRST_ID, _s, 0);
        assertEq(decompressor.decompressSender(compressed), _s);
    }

    function testNonceCompresssion() public {
        uint256 nonce = uint192(0x1234567890abcdef) << 64 | uint64(0);
        bytes memory compressed = decompressor.compressNonce(nonce);
        assertEq(nonce, decompressor.decompressNonce(compressed, address(0)));
    }

    function testPreVerificationGasCompression(uint256 _preVerificationGas) public {
        vm.assume((_preVerificationGas >> (decompressor.PRE_VERIFICATION_GAS_REPRESENTATION_SIZE_BYTES() * 8)) == 0);
        bytes memory compressed = decompressor.compressPreVerificationGas(_preVerificationGas);
        assertEq(_preVerificationGas, decompressor.decompressPreVerificationGas(compressed));
    }

    function testVerificationGasLimitCompression(uint256 _verificationGasLimitMultiplier) public {
        vm.assume(
            (_verificationGasLimitMultiplier >> (decompressor.VERIFICATION_GAS_LIMIT_REPRESENTATION_SIZE_BYTES() * 8))
                == 0
        );

        uint256 verificationGasLimit =
            _verificationGasLimitMultiplier * decompressor.VERIFICATION_GAS_LIMIT_MULTIPLIER();
        bytes memory compressed = decompressor.compressVerificationGasLimit(verificationGasLimit);
        assertEq(verificationGasLimit, decompressor.decompressVerificationGasLimit(compressed));
    }

    function testShouldNotAcceptVerificationGasLimitNotMultipleOfMultiplier(uint256 _verificationGasLimitMultiplier)
        public
    {
        vm.assume(
            (_verificationGasLimitMultiplier >> (decompressor.VERIFICATION_GAS_LIMIT_REPRESENTATION_SIZE_BYTES() * 8))
                == 0
        );

        uint256 verificationGasLimit =
            _verificationGasLimitMultiplier * decompressor.VERIFICATION_GAS_LIMIT_MULTIPLIER() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEP6Decompressor.ValueNotAnExactMultipleOfMultiplier.selector,
                verificationGasLimit,
                decompressor.VERIFICATION_GAS_LIMIT_MULTIPLIER()
            )
        );
        decompressor.compressVerificationGasLimit(verificationGasLimit);
    }

    function testCallGasLimitCompression(uint256 _callGasLimitMultiplier) public {
        vm.assume((_callGasLimitMultiplier >> (decompressor.CALL_GAS_LIMIT_REPRESENTATION_SIZE_BYTES() * 8)) == 0);

        uint256 callGasLimit = _callGasLimitMultiplier * decompressor.CALL_GAS_LIMIT_MULTIPLIER();
        bytes memory compressed = decompressor.compressCallGasLimit(callGasLimit);
        assertEq(callGasLimit, decompressor.decompressCallGasLimit(compressed));
    }

    function testShouldNotAcceptCallGasLimitNotMultipleOfMultiplier(uint256 _callGasLimitMultiplier) public {
        vm.assume((_callGasLimitMultiplier >> (decompressor.CALL_GAS_LIMIT_REPRESENTATION_SIZE_BYTES() * 8)) == 0);

        uint256 callGasLimit = _callGasLimitMultiplier * decompressor.CALL_GAS_LIMIT_MULTIPLIER() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEP6Decompressor.ValueNotAnExactMultipleOfMultiplier.selector,
                callGasLimit,
                decompressor.CALL_GAS_LIMIT_MULTIPLIER()
            )
        );
        decompressor.compressCallGasLimit(callGasLimit);
    }

    function testMaxFeePerGasCompression(uint256 _maxFeePerGasMultiplier) public {
        vm.assume((_maxFeePerGasMultiplier >> (decompressor.MAX_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES() * 8)) == 0);

        uint256 maxFeePerGas = _maxFeePerGasMultiplier * decompressor.MAX_FEE_PER_GAS_MULTIPLIER();
        bytes memory compressed = decompressor.compressMaxFeePerGas(maxFeePerGas);
        assertEq(maxFeePerGas, decompressor.decompressMaxFeePerGas(compressed));
    }

    function testShouldNotAcceptMaxFeePerGasNotMultipleOfMultiplier(uint256 _maxFeePerGasMultiplier) public {
        vm.assume((_maxFeePerGasMultiplier >> (decompressor.MAX_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES() * 8)) == 0);

        uint256 maxFeePerGas = _maxFeePerGasMultiplier * decompressor.MAX_FEE_PER_GAS_MULTIPLIER() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEP6Decompressor.ValueNotAnExactMultipleOfMultiplier.selector,
                maxFeePerGas,
                decompressor.MAX_FEE_PER_GAS_MULTIPLIER()
            )
        );
        decompressor.compressMaxFeePerGas(maxFeePerGas);
    }

    function testMaxPriorityFeePerGasCompression(uint256 _maxPriorityFeePerGasMultiplier) public {
        vm.assume(
            (_maxPriorityFeePerGasMultiplier >> (decompressor.MAX_PRIORITY_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES() * 8))
                == 0
        );

        uint256 maxPriorityFeePerGas =
            _maxPriorityFeePerGasMultiplier * decompressor.MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER();
        bytes memory compressed = decompressor.compressMaxPriorityFeePerGas(maxPriorityFeePerGas);
        assertEq(maxPriorityFeePerGas, decompressor.decompressMaxPriorityFeePerGas(compressed));
    }

    function testShouldNotAcceptMaxPriorityFeePerGasNotMultipleOfMultiplier(uint256 _maxPriorityFeePerGasMultiplier)
        public
    {
        vm.assume(
            (_maxPriorityFeePerGasMultiplier >> (decompressor.MAX_PRIORITY_FEE_PER_GAS_REPRESENTATION_SIZE_BYTES() * 8))
                == 0
        );

        uint256 maxPriorityFeePerGas =
            _maxPriorityFeePerGasMultiplier * decompressor.MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEP6Decompressor.ValueNotAnExactMultipleOfMultiplier.selector,
                maxPriorityFeePerGas,
                decompressor.MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER()
            )
        );
        decompressor.compressMaxPriorityFeePerGas(maxPriorityFeePerGas);
    }

    function testUserOperationCompression(uint8 _userOpCount) public {
        vm.assume(_userOpCount >> (decompressor.BUNDLE_LENGTH_REPRESENTATION_SIZE_BYTES() * 8) == 0);

        UserOperation[] memory ops = new UserOperation[](_userOpCount);
        IEP6Decompressor.CompressionOptions[] memory options = new IEP6Decompressor.CompressionOptions[](_userOpCount);

        for (uint8 i = 0; i < _userOpCount; i++) {
            unchecked {
                ops[i] = UserOperation({
                    sender: vm.addr(uint256(bytes32(keccak256(abi.encodePacked(i))))),
                    nonce: uint256(uint192(uint256(bytes32(keccak256(abi.encodePacked(i * 2)))))) << 64,
                    preVerificationGas: uint40(uint256(bytes32(keccak256(abi.encodePacked(i * 3))))),
                    verificationGasLimit: uint256(uint8(uint256(bytes32(keccak256(abi.encodePacked(i * 4))))))
                        * decompressor.VERIFICATION_GAS_LIMIT_MULTIPLIER(),
                    callGasLimit: uint256(uint8(uint256(bytes32(keccak256(abi.encodePacked(i * 5))))))
                        * decompressor.CALL_GAS_LIMIT_MULTIPLIER(),
                    maxPriorityFeePerGas: uint256(uint32(uint256(bytes32(keccak256(abi.encodePacked(i * 6))))))
                        * decompressor.MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER(),
                    maxFeePerGas: uint256(uint32(uint256(bytes32(keccak256(abi.encodePacked(i * 7))))))
                        * decompressor.MAX_FEE_PER_GAS_MULTIPLIER(),
                    initCode: _randomBytes(10),
                    callData: _randomBytes(15),
                    signature: _randomBytes(20),
                    paymasterAndData: _randomBytes(25)
                });
            }

            options[i] = IEP6Decompressor.CompressionOptions({
                paymasterAndDataDecompressor: paymasterAndDataCompressor,
                signatureDecompressor: signatureCompressor,
                initCodeDecompressor: initcodeCompressor,
                callDataDecompressor: calldataCompressor
            });
        }

        // Compress the User Operations
        for (uint256 i = 0; i < _userOpCount; i++) {
            for (uint256 j = 0; j < 4; ++j) {
                vm.expectEmit();
                emit Decompressor.Compress();
            }
        }
        bytes memory compressed = decompressor.compressOps(ops, options);

        // Decompress the User Operations
        for (uint256 i = 0; i < _userOpCount; i++) {
            for (uint256 j = 0; j < 4; ++j) {
                vm.expectEmit();
                emit Decompressor.Decompress();
            }
        }
        UserOperation[] memory decompressedOps = decompressor.decompressOps(compressed);
        assertEq(decompressedOps.length, _userOpCount);
        for (uint256 i = 0; i < _userOpCount; i++) {
            assertEq(decompressedOps[i].sender, ops[i].sender);
        }

        if (_userOpCount == 0) {
            return;
        }

        // Compress the User Operations again with pre-registered decompressors
        assertEq(decompressor.paymasterDecompressorId(paymasterAndDataCompressor), 0x100);
        assertEq(decompressor.signatureDecompressorId(signatureCompressor), 0x100);
        assertEq(decompressor.initCodeDecompressorId(initcodeCompressor), 0x100);
        assertEq(decompressor.callDataDecompressorId(calldataCompressor), 0x100);

        // Compress the User Operations
        for (uint256 i = 0; i < _userOpCount; i++) {
            for (uint256 j = 0; j < 4; ++j) {
                vm.expectEmit();
                emit Decompressor.Compress();
            }
        }
        compressed = decompressor.compressOps(ops, options);

        // Decompress the User Operations
        for (uint256 i = 0; i < _userOpCount; i++) {
            for (uint256 j = 0; j < 4; ++j) {
                vm.expectEmit();
                emit Decompressor.Decompress();
            }
        }
        decompressedOps = decompressor.decompressOps(compressed);
        assertEq(decompressedOps.length, _userOpCount);
        for (uint256 i = 0; i < _userOpCount; i++) {
            assertEq(decompressedOps[i].sender, ops[i].sender);
        }
    }

    function testSimulateHandleCompressedOpShouldRevertWithAppropriateData() public {
        UserOperation memory op = UserOperation({
            sender: vm.addr(uint256(bytes32(keccak256(abi.encodePacked(uint256(1)))))),
            nonce: uint256(uint192(uint256(bytes32(keccak256(abi.encodePacked(uint256(2))))))) << 64,
            preVerificationGas: uint40(uint256(bytes32(keccak256(abi.encodePacked(uint256(3)))))),
            verificationGasLimit: uint256(uint8(uint256(bytes32(keccak256(abi.encodePacked(uint256(4)))))))
                * decompressor.VERIFICATION_GAS_LIMIT_MULTIPLIER(),
            callGasLimit: uint256(uint8(uint256(bytes32(keccak256(abi.encodePacked(uint256(5)))))))
                * decompressor.CALL_GAS_LIMIT_MULTIPLIER(),
            maxPriorityFeePerGas: uint256(uint32(uint256(bytes32(keccak256(abi.encodePacked(uint256(6)))))))
                * decompressor.MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER(),
            maxFeePerGas: uint256(uint32(uint256(bytes32(keccak256(abi.encodePacked(uint256(7)))))))
                * decompressor.MAX_FEE_PER_GAS_MULTIPLIER(),
            initCode: _randomBytes(10),
            callData: _randomBytes(15),
            signature: _randomBytes(20),
            paymasterAndData: _randomBytes(25)
        });

        IEP6Decompressor.CompressionOptions memory options = IEP6Decompressor.CompressionOptions({
            paymasterAndDataDecompressor: paymasterAndDataCompressor,
            signatureDecompressor: signatureCompressor,
            initCodeDecompressor: initcodeCompressor,
            callDataDecompressor: calldataCompressor
        });
        bytes memory compressedOp = decompressor.compressOps(toArray(op), toArray(options));

        vm.expectRevert(
            abi.encodeWithSelector(
                IEP6Decompressor.ExecutionResultWithUserOperation.selector, 1, 2, 3, 4, false, "0x", op
            )
        );
        decompressor.simulateHandleCompressedOp(compressedOp.slice(1, compressedOp.length - 1), address(0), bytes(""));
    }

    function testSimulateValidationShouldRevertWithAppropriateData() public {
        UserOperation memory op = UserOperation({
            sender: vm.addr(uint256(bytes32(keccak256(abi.encodePacked(uint256(1)))))),
            nonce: uint256(uint192(uint256(bytes32(keccak256(abi.encodePacked(uint256(2))))))) << 64,
            preVerificationGas: uint40(uint256(bytes32(keccak256(abi.encodePacked(uint256(3)))))),
            verificationGasLimit: uint256(uint8(uint256(bytes32(keccak256(abi.encodePacked(uint256(4)))))))
                * decompressor.VERIFICATION_GAS_LIMIT_MULTIPLIER(),
            callGasLimit: uint256(uint8(uint256(bytes32(keccak256(abi.encodePacked(uint256(5)))))))
                * decompressor.CALL_GAS_LIMIT_MULTIPLIER(),
            maxPriorityFeePerGas: uint256(uint32(uint256(bytes32(keccak256(abi.encodePacked(uint256(6)))))))
                * decompressor.MAX_PRIORITY_FEE_PER_GAS_MULTIPLIER(),
            maxFeePerGas: uint256(uint32(uint256(bytes32(keccak256(abi.encodePacked(uint256(7)))))))
                * decompressor.MAX_FEE_PER_GAS_MULTIPLIER(),
            initCode: _randomBytes(10),
            callData: _randomBytes(15),
            signature: _randomBytes(20),
            paymasterAndData: _randomBytes(25)
        });

        IEP6Decompressor.CompressionOptions memory options = IEP6Decompressor.CompressionOptions({
            paymasterAndDataDecompressor: paymasterAndDataCompressor,
            signatureDecompressor: signatureCompressor,
            initCodeDecompressor: initcodeCompressor,
            callDataDecompressor: calldataCompressor
        });
        bytes memory compressedOp = decompressor.compressOps(toArray(op), toArray(options));

        vm.expectRevert(
            abi.encodeWithSelector(
                IEP6Decompressor.ValidationResultWithUserOperation.selector,
                entryPointV6.returnInfo(),
                entryPointV6.senderInfo(),
                entryPointV6.factoryInfo(),
                entryPointV6.paymasterInfo(),
                op
            )
        );
        decompressor.simulateValidationCompressedOp(compressedOp.slice(1, compressedOp.length - 1));
    }

    function _randomBytes(uint256 _length) internal pure returns (bytes memory) {
        bytes memory data = new bytes(_length);
        for (uint256 i = 0; i < _length; i++) {
            data[i] = bytes1(uint8(uint256(bytes32(keccak256(abi.encodePacked(i))))));
        }
        return data;
    }
}

contract EntryPointStub {
    struct ReturnInfo {
        uint256 preOpGas;
        uint256 prefund;
        bool sigFailed;
        uint48 validAfter;
        uint48 validUntil;
        bytes paymasterContext;
    }

    struct StakeInfo {
        uint256 stake;
        uint256 unstakeDelaySec;
    }

    error ValidationResult(ReturnInfo returnInfo, StakeInfo senderInfo, StakeInfo factoryInfo, StakeInfo paymasterInfo);
    error ExecutionResult(
        uint256 preOpGas, uint256 paid, uint48 validAfter, uint48 validUntil, bool targetSuccess, bytes targetResult
    );

    address public beneficiary;
    UserOperation[] private _ops;

    ReturnInfo _returnInfo = ReturnInfo(1, 2, false, 3, 4, "0x");
    StakeInfo _senderInfo = StakeInfo(5, 6);
    StakeInfo _factoryInfo = StakeInfo(7, 8);
    StakeInfo _paymasterInfo = StakeInfo(9, 10);

    function handleOps(UserOperation[] calldata ops, address payable _beneficiary) external {
        beneficiary = _beneficiary;
        _ops = ops;
    }

    function getNonce(address, uint192 key) external pure returns (uint256) {
        return 0 | (uint256(key) << 64);
    }

    function userOps() external view returns (UserOperation[] memory) {
        return _ops;
    }

    function simulateValidation(UserOperation calldata) external view {
        revert ValidationResult(_returnInfo, _senderInfo, _factoryInfo, _paymasterInfo);
    }

    function simulateHandleOp(UserOperation calldata, address, bytes calldata) external pure {
        revert ExecutionResult(1, 2, 3, 4, false, "0x");
    }

    function returnInfo() external view returns (ReturnInfo memory) {
        return _returnInfo;
    }

    function senderInfo() external view returns (StakeInfo memory) {
        return _senderInfo;
    }

    function factoryInfo() external view returns (StakeInfo memory) {
        return _factoryInfo;
    }

    function paymasterInfo() external view returns (StakeInfo memory) {
        return _paymasterInfo;
    }
}

contract Decompressor is IDecompressor {
    uint256 nextId = 1;
    mapping(uint256 => bytes) private _decompressed;

    event Compress();
    event Decompress();

    function decompress(bytes calldata _slice) external override returns (bytes memory) {
        uint256 id = abi.decode(_slice, (uint256));
        emit Decompress();
        return _decompressed[id];
    }

    function compress(bytes calldata _data) external override returns (bytes memory compressed) {
        compressed = abi.encode(nextId);
        emit Compress();
        _decompressed[nextId++] = _data;
    }
}

contract EP6DecompressorWrapper is EP6Decompressor {
    constructor(IEntryPoint _entryPointV6, EP6DecompressorConfiguration memory _config)
        EP6Decompressor(_entryPointV6, _config)
    {}

    function decompressSender(bytes calldata _data) external returns (address sender) {
        (sender,) = _decompressSender(_data);
    }

    function compressSender(address _sender) external view returns (bytes memory data) {
        data = _compressSender(_sender);
    }

    function decompressNonce(bytes calldata _data, address _sender) external view returns (uint256 nonce) {
        (nonce,) = _decompressNonce(_data, _sender);
    }

    function compressNonce(uint256 _nonce) external pure returns (bytes memory data) {
        data = _compressNonce(_nonce);
    }

    function decompressPreVerificationGas(bytes calldata _slice) external pure returns (uint256 preVerificationGas) {
        (preVerificationGas,) = _decompressPreVerificationGas(_slice);
    }

    function compressPreVerificationGas(uint256 _preVerificationGas) external pure returns (bytes memory slice) {
        slice = _compressPreVerificationGas(_preVerificationGas);
    }

    function decompressVerificationGasLimit(bytes calldata _slice)
        external
        pure
        returns (uint256 verificationGasLimit)
    {
        (verificationGasLimit,) = _decompressVerificationGasLimit(_slice);
    }

    function compressVerificationGasLimit(uint256 _verificationGasLimit) external pure returns (bytes memory slice) {
        slice = _compressVerificationGasLimit(_verificationGasLimit);
    }

    function decompressCallGasLimit(bytes calldata _slice) external pure returns (uint256 callGasLimit) {
        (callGasLimit,) = _decompressCallGasLimit(_slice);
    }

    function compressCallGasLimit(uint256 _callGasLimit) external pure returns (bytes memory slice) {
        slice = _compressCallGasLimit(_callGasLimit);
    }

    function decompressMaxPriorityFeePerGas(bytes calldata _slice)
        external
        pure
        returns (uint256 maxPriorityFeePerGas)
    {
        (maxPriorityFeePerGas,) = _decompressMaxPriorityFeePerGas(_slice);
    }

    function compressMaxPriorityFeePerGas(uint256 _maxPriorityFeePerGas) external pure returns (bytes memory slice) {
        slice = _compressMaxPriorityFeePerGas(_maxPriorityFeePerGas);
    }

    function decompressMaxFeePerGas(bytes calldata _slice) external pure returns (uint256 maxFeePerGas) {
        (maxFeePerGas,) = _decompressMaxFeePerGas(_slice);
    }

    function compressMaxFeePerGas(uint256 _maxFeePerGas) external pure returns (bytes memory slice) {
        slice = _compressMaxFeePerGas(_maxFeePerGas);
    }

    function decompressInitcode(bytes calldata _slice) external returns (bytes memory initcode) {
        (initcode,) = _decompressInitcode(_slice);
    }

    function compressInitcode(bytes calldata _initcode, IDecompressor _decompressor)
        external
        returns (bytes memory slice)
    {
        slice = _compressInitcode(_initcode, _decompressor);
    }

    function decompressCallData(bytes calldata _slice) external returns (bytes memory callData) {
        (callData,) = _decompressCalldata(_slice);
    }

    function compressCallData(bytes calldata _callData, IDecompressor _decompressor)
        external
        returns (bytes memory slice)
    {
        slice = _compressCalldata(_callData, _decompressor);
    }

    function decompressSignature(bytes calldata _slice) external returns (bytes memory signature) {
        (signature,) = _decompressSignature(_slice);
    }

    function compressSignature(bytes calldata _signature, IDecompressor _decompressor)
        external
        returns (bytes memory slice)
    {
        slice = _compressSignature(_signature, _decompressor);
    }

    function decompressPaymasterAndData(bytes calldata _slice) external returns (bytes memory pmd) {
        (pmd,) = _decompressPaymasterAndData(_slice);
    }

    function compressPaymasterAndData(bytes calldata _pmd, IDecompressor _decompressor)
        external
        returns (bytes memory slice)
    {
        slice = _compressPaymasterAndData(_pmd, _decompressor);
    }
}
