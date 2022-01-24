// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Using OpenZeppelin Implementation for security
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract RoyalToken is ERC20, ERC20Burnable, Ownable {
    address public distributionContract;  
    using SafeERC20 for IERC20;

    constructor () ERC20("Royal Token", "ROYAL") {

    }

    /**
     * @notice Sets the distribution contract.
     * @param _address address of the Distribution contract
     */
    function setDistributionContract(address _address) public onlyOwner {
        require(_address != address(0), "RoyalToken: Distribution contract address cannot be empty!"); 
        require(distributionContract == address(0), "RoyalToken: Distribution contract address has already been set!");
        distributionContract = _address;
        _mint(_address, 2 * (10**11) * (10 ** uint256(decimals())));
    }
}