// Copyright (C) 2015, 2016, 2017 Dapphub

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.4.18;

import "../interfaces/ApproveAndCallFallBack.sol";
import "../interfaces/ERC223ReceivingContract.sol";
import "../interfaces/ERC223.sol";

contract WCKTON is ERC223 {
    string  public name            = "Wrapped CKTON";
    string  public symbol          = "WCKTON";
    uint8   public decimals        = 9;
    address public KTON_PRECOMPILE = 0x0000000000000000000000000000000000000016;

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);
    event  Deposit(address indexed dst, uint wad);
    event  Withdrawal(bytes32 indexed src, uint wad);

    uint                                           public totalSupply;
    mapping (address => uint)                      public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;

    function deposit(address from, uint256 value) public {
	require(msg.sender == KTON_PRECOMPILE, "WKTON: PERMISSION");
	totalSupply += value;
        balanceOf[from] += value;
        Deposit(from, value);
    }
    function withdraw(bytes32 to, uint wad) public {
        require(balanceOf[msg.sender] >= wad);
	totalSupply -= wad;
        balanceOf[msg.sender] -= wad;
	bool success = KTON_PRECOMPILE.call(bytes4(keccak256("withdraw(bytes32,uint256)")), to, wad);
	require(success, "WKTON: WITHDRAW_FAILED");
        Withdrawal(to, wad);
    }

    function totalSupply() public view returns (uint) {
        return totalSupply;
    }

    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
        require(balanceOf[src] >= wad);

        if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        Transfer(src, dst, wad);

        return true;
    }

    function approveAndCall(address _spender, uint256 _amount, bytes _extraData)
		returns (bool success)
	{
        if (!approve(_spender, _amount)) revert();

        ApproveAndCallFallBack(_spender).receiveApproval(
            msg.sender,
            _amount,
            this,
            _extraData
        );

        return true;
    }

    function transfer(
        address _to,
        uint256 _amount,
        bytes _data)
        public
        returns (bool success)
    {
        return transferFrom(msg.sender, _to, _amount, _data);
    }

    function transferFrom(address _from, address _to, uint256 _amount, bytes _data)
        public 
        returns (bool success)
    {
        require(transferFrom(_from, _to, _amount));
        if (isContract(_to)) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            receiver.tokenFallback(_from, _amount, _data);
        }
        ERC223Transfer(_from, _to, _amount, _data);
        return true;
    }

    function isContract(address _addr) constant internal returns(bool) {
        uint size;
        if (_addr == 0) return false;
        assembly {
            size := extcodesize(_addr)
        }
        return size>0;
    }
}