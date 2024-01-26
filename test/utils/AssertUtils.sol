// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UserOperation} from "account-abstraction/interfaces/IEntryPoint.sol";
import "forge-std/Test.sol";

contract AssertUtils is Test {
    function assertEq(UserOperation memory _a, UserOperation memory _b) internal {
        assertEq(_a.sender, _b.sender, "Sender mismatch");
        assertEq(_a.nonce, _b.nonce, "Nonce mismatch");
        assertEq(_a.preVerificationGas, _b.preVerificationGas, "PVG mismatch");
        assertEq(_a.verificationGasLimit, _b.verificationGasLimit, "Verification gas limit mismatch");
        assertEq(_a.callGasLimit, _b.callGasLimit, "Call gas limit mismatch");
        assertEq(_a.maxFeePerGas, _b.maxFeePerGas, "Max fee per gas mismatch");
        assertEq(_a.maxPriorityFeePerGas, _b.maxPriorityFeePerGas, "Max priority fee per gas mismatch");
        assertEq(_a.callData, _b.callData, "Call data mismatch");
        assertEq(_a.paymasterAndData, _b.paymasterAndData, "Paymaster and data mismatch");
        assertEq(_a.signature, _b.signature, "Signature mismatch");
        assertEq(_a.initCode, _b.initCode, "Initcode mismatch");
    }
}
