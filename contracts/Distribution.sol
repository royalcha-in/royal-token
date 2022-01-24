// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// Using OpenZeppelin Implementation for security
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

 
 contract Distribution is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool private repartitionDone = false;
    uint256 private constant secondsOfDay = 86400;
    uint256 public startDate = getCurrentTime();
    
    address public constant preSaleAddress = 0x146b77b050a9985922e980E62925F4c56E2b848A; 
    address public constant exchangesAndLiquidityAddress = 0x8D02034E502E2d21DAe0c4ac5e609954b6c12A9e; 
    address public constant referencesAndBonusesAddress = 0x05B4aed6dfc2c10d672594634AcA625F64e6D7AA;
    address public constant advertisingAndMarketingAddress = 0x46196b46BAAaF581915d8F946F3F1BE5F507F531;
    address public constant royalChainV2AndMetaverseAddress = 0xf363Ab85380080fc0E7b570110A4F826370A3b47;
    address public constant reserveAddress = 0xF8F3d482906D9c6c9b95a76d1d933Fb9F1fBd91d; 
    address public constant teamAndDevelopersAddress = 0x2a55B878dc3Bf97CbF294417a325a64F86287B8a;
    
    uint16 public constant percentageOfPreSale = 5;
    uint16 public constant percentageOfExchangesAndLiquidity = 15;    
    uint16 public constant percentageOfReferencesAndBonuses = 5;
    uint16 public constant percentageOfAdvertisingAndMarketing = 20;
    uint16 public constant percentageOfRoyalChainV2AndMetaverse = 27;
    uint16 public constant percentageOfReserve = 13;
    uint16 public constant percentageOfTeamAndDevelopers = 15;

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
     * @notice Creates vesting shcedule and distributes the supply.
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

        uint256 totalAmountOfExchangesAndLiquidty = totalSupplyPercentageUnit.mul(percentageOfExchangesAndLiquidity);
        _token.safeTransfer(exchangesAndLiquidityAddress, totalAmountOfExchangesAndLiquidty);

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

        repartitionDone = true;
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