// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

// Using OpenZeppelin Implementation for security
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

 
 contract Distribution is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool private repartitionDone = false;
    uint256 private secondsOfDay = 86400;
    uint256 public startDate = getCurrentTime();
    
    address public immutable preSaleAddress = 0xd7eb6B2814B2461196e868240e095a951C13f843; 
    address public immutable exchangesAndLiquidtyAddress = 0x6cC5Fa8e39982CC8D7BAD053dDf359174aB6EB89; 
    address public immutable referencesAndBonusesAddress = 0x3D07210f949Ffa1519DcE7e5b27fc0F68cee8B15;
    address public immutable advertisingAndMarketingAddress = 0x237Ee27c074Ae57A9607be08aA86c1a94d1881cA;
    address public immutable royalChainV2AndMetaverseAddress = 0xB1857941e3110E60AD45eD650968F8659f2f5F16;
    address public immutable reserveAddress = 0x1f7CbEA7B064f327CE564f31bd5aCf88A785B2F0; 
    address public immutable teamAndDevelopersAddress = 0xE3D2c0A452e7993efBc3512c25DC3cd2CCF08F90;
    
    uint16 public immutable percentageOfPreSale = 5;
    uint16 public immutable percentageOfExchangesAndLiquidty = 15;    
    uint16 public immutable percentageOfReferencesAndBonuses = 5;
    uint16 public immutable percentageOfAdvertisingAndMarketing = 20;
    uint16 public immutable percentageOfRoyalChainV2AndMetaverse = 27;
    uint16 public immutable percentageOfReserve = 13;
    uint16 public immutable percentageOfTeamAndDevelopers = 15;

    struct TimeLockSchedule{
        bool initialized;    // whether or not the vesting has been released
        address beneficiary; // beneficiary of tokens after they are released
        uint256 amount;      // period amount
        uint256 releaseTime; // period releasedTime in seconds.
    }
    
    struct DispersantsModel {
        uint256 perThousand; // share of dispersant
        address beneficiary; // address of dispersant
        uint256 start;       // time of starting period
        string name;         // name of dispersant                   
        uint256 totalAmount; // total amount
        uint256 size;        // period time
        mapping(uint256 => TimeLockSchedule) schedules; // period timelocks schedules
    }

    IERC20 immutable private _token; // Adress Of RoyalToken
    
    mapping(address => DispersantsModel) private dispersants;

    /**
     * @notice Emit event when released period.
     * @return amount of claimed amount
     * @return name of Dispersant
     */
    event Released(uint256 amount, string name);

    /**
     * @notice Creates a Distribution contract.
     * @param token_ address of the RoyalToken contract
     */
    constructor(address token_) {
        require(token_ != address(0x0));
        _token = IERC20(token_);
    }

    /**
     * @notice Creates a new vesting schedule for a beneficiary.
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _fraction how much part of period
     * @param _start start time of the vesting period
     * @param _period duration of a slice period for the vesting in seconds
     * @param _percentage percentage of account 
     * @param _name total amount of tokens to be released at the end of the vesting
     * @param _amount total amount of tokens to be released at the end of the vesting
     */
    function createTimeLock(
        address _beneficiary,
        uint8 _fraction,
        uint16 _percentage,
        uint256 _start,
        uint256 _period,
        string memory _name,
        uint256 _amount
    ) internal {
        uint256 periodAmount = _amount.div(_fraction);

        DispersantsModel storage dM = dispersants[_beneficiary];
        dM.beneficiary = _beneficiary;
        dM.name = _name;
        dM.perThousand = _percentage;
        dM.size = _fraction;
        dM.start = _start;
        dM.totalAmount = _amount;
       
        for (uint256 index = 0; index < _fraction; index++) {
            dispersants[_beneficiary].schedules[index] = TimeLockSchedule({
                initialized: false,
                beneficiary: _beneficiary,
                amount: periodAmount,
                releaseTime: _start + (_period.mul(index+1))
            }); 
        }
    }

    /**
     * @notice Release vested amount of tokens.
     * @param _beneficiary address of the beneficiary to whom vested tokens will release
     */
    function release(address _beneficiary) public { 
        require(_beneficiary != address(0), "Distribution: Beneficiary address cannot be empty!"); 
        require(dispersants[_beneficiary].beneficiary != address(0x0),"Distribution: Beneficiary address is not a member!");

        bool isBeneficiary = msg.sender == dispersants[_beneficiary].beneficiary;
        bool isOwner = msg.sender == owner();

        require(isBeneficiary || isOwner, "Distribution: Only beneficiary and owner can release vested tokens!");

        uint256 amount = 0;
        for (uint256 index = 0; index < dispersants[_beneficiary].size; index++) {
            if (dispersants[_beneficiary].schedules[index].initialized) continue;
            if (getCurrentTime() < dispersants[_beneficiary].schedules[index].releaseTime) break;
            amount = amount.add(dispersants[_beneficiary].schedules[index].amount);
            dispersants[_beneficiary].schedules[index].initialized = true;
        }

        require(_token.balanceOf(address(this)) >= amount, "Distribution: Distribution contract does not have funds!");

        if (amount == 0) {
            revert("Distribution: There is nothing to claim!");
        }

        _token.safeTransfer(dispersants[_beneficiary].beneficiary, amount);
        emit Released(amount, dispersants[_beneficiary].name);
    }

    /**
     * @notice Creates vesting shcedules and distributes the supply.
     */
    function repartition() public onlyOwner {
        require(repartitionDone != true, "Distribution: Repartition has already done!");

        uint256 totalSupply = _token.balanceOf(address(this));
        require(totalSupply != 0, "Distribution: There is nothing to repartite!");

        uint256 totalSupplyPercentageUnit = totalSupply.div(100);

        uint256 totalAmountOfPreSale = totalSupplyPercentageUnit.mul(percentageOfPreSale);
        _token.safeTransfer(preSaleAddress, totalAmountOfPreSale);

        uint256 totalAmountOfReferencesAndBonuses = totalSupplyPercentageUnit.mul(percentageOfReferencesAndBonuses);
        _token.safeTransfer(referencesAndBonusesAddress, totalAmountOfReferencesAndBonuses);

        uint256 totalAmountOfExchangesAndLiquidty = totalSupplyPercentageUnit.mul(percentageOfExchangesAndLiquidty);
        _token.safeTransfer(exchangesAndLiquidtyAddress, totalAmountOfExchangesAndLiquidty);

        uint256 totalAmountOfReserve = totalSupplyPercentageUnit.mul(percentageOfReserve);
        uint8 divisionMonthOfReserve = 2;
        createTimeLock({
            _beneficiary: reserveAddress,
            _fraction: divisionMonthOfReserve,
            _percentage: percentageOfReserve,
            _start: startDate + (secondsOfDay * 30 * 3), // 4 months after starting
            _period: (secondsOfDay * 30 * 1),
            _name: "Reserve",
            _amount: totalAmountOfReserve
        });

        uint256 totalAmountOfTeamAndDevelopers = totalSupplyPercentageUnit.mul(percentageOfTeamAndDevelopers);
        uint8 divisionMonthOfTeamAndDevelopers = 12;
        createTimeLock({
            _beneficiary: teamAndDevelopersAddress,
            _fraction: divisionMonthOfTeamAndDevelopers,
            _percentage: percentageOfTeamAndDevelopers,
            _start: startDate + (secondsOfDay * 30 * 11), // 12 months after starting
            _period: (secondsOfDay * 30 * 1),
            _name: "TeamAndDevelopers",
            _amount: totalAmountOfTeamAndDevelopers
        });

        uint256 totalAmountOfAdvertisingAndMarketing = totalSupplyPercentageUnit.mul(percentageOfAdvertisingAndMarketing);
        uint8 divisionMonthOfAdvertisingAndMarketing = 50;
        createTimeLock(
            advertisingAndMarketingAddress,
            divisionMonthOfAdvertisingAndMarketing,
            percentageOfAdvertisingAndMarketing,
            startDate + (secondsOfDay * 30 * 0), // 1 month after starting
            (secondsOfDay * 30 * 1),
            "AdvertisingAndMarketing",
            totalAmountOfAdvertisingAndMarketing
        );

        uint256 totalAmountOfRoyalChainV2AndMetaverse = totalSupplyPercentageUnit.mul(percentageOfRoyalChainV2AndMetaverse);
        uint8 divisionMonthOfRoyalChainV2AndMetaverse = 25;
        createTimeLock(
            royalChainV2AndMetaverseAddress,
            divisionMonthOfRoyalChainV2AndMetaverse,
            percentageOfRoyalChainV2AndMetaverse,
            startDate + (secondsOfDay * 30 * 0), // 1 month after starting
            (secondsOfDay * 30 * 1),
            "RoyalChainV2AndMetaverse",
            totalAmountOfRoyalChainV2AndMetaverse
        );
    }

    /**
     * @notice Returns the address of the RoyalToken managed by the distribution contract.
     */
    function getToken() external view returns(address) {
        return address(_token);
    }

    /**
     * @notice Returns the timestamp of current block time.
     */  
    function getCurrentTime() internal virtual view returns(uint256) {
        return block.timestamp;
    }
}