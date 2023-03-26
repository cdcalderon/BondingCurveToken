// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
//import "@openzeppelin/contracts/token/ERC1363/IERC1363Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC1363Receiver.sol";

contract CurveToken is ERC777, IERC1363Receiver, Ownable {
    uint256 public tokenPrice;
    uint256 public reserve;

    constructor(
        uint256 initialSupply,
        address[] memory defaultOperators,
        uint256 _tokenPrice
    ) ERC777("MyToken", "MTK", defaultOperators) {
        _mint(msg.sender, initialSupply, "", "");
        tokenPrice = _tokenPrice;
    }

    function buyTokens(uint256 amount) public payable {
        uint256 totalPrice = amount * tokenPrice;
        require(msg.value >= totalPrice, "Insufficient payment");

        reserve += msg.value;
        _mint(msg.sender, amount, "", "");
    }

    function sellTokens(uint256 amount) public {
        uint256 payment = amount * tokenPrice;
        require(payment <= reserve, "Insufficient reserve");

        reserve -= payment;
        _burn(msg.sender, amount, "", "");
        payable(msg.sender).transfer(payment);
    }

    function onTransferReceived(
        address /* operator */,
        address /* from */,
        uint256 amount,
        bytes memory data
    ) public virtual override returns (bytes4) {
        if (msg.sender == address(this)) {
            // Token sale and buyback
            return this.onTokensReceived.selector;
        } else {
            // Token transfer to contract
            require(data.length == 0, "Data not supported");
            _mint(address(this), amount, "", "");
            return this.onTokensReceived.selector;
        }
    }

    function onTokensReceived(
        address /* operator */,
        address /* from */,
        uint256 /* amount */,
        bytes memory data,
        bytes memory /*operatorData*/
    ) public virtual returns (bytes4) {
        require(msg.sender == address(this), "Invalid token");
        require(data.length == 0, "Data not supported");

        return this.onTokensReceived.selector;
    }

    function withdraw(uint256 amount) public onlyOwner {
        require(amount <= reserve, "Insufficient reserve");
        reserve -= amount;
        payable(msg.sender).transfer(amount);
    }
}
