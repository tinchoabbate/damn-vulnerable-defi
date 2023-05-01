// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "solady/src/utils/LibSort.sol";

/**
 * @title TrustfulOracle
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @notice A price oracle with a number of trusted sources that individually report prices for symbols.
 *         The oracle's price for a given symbol is the median price of the symbol over all sources.
 */
contract TrustfulOracle is AccessControlEnumerable {
    uint256 public constant MIN_SOURCES = 1;
    bytes32 public constant TRUSTED_SOURCE_ROLE = keccak256("TRUSTED_SOURCE_ROLE");
    bytes32 public constant INITIALIZER_ROLE = keccak256("INITIALIZER_ROLE");

    // Source address => (symbol => price)
    mapping(address => mapping(string => uint256)) private _pricesBySource;

    error NotEnoughSources();

    event UpdatedPrice(address indexed source, string indexed symbol, uint256 oldPrice, uint256 newPrice);

    constructor(address[] memory sources, bool enableInitialization) {
        if (sources.length < MIN_SOURCES)
            revert NotEnoughSources();
        for (uint256 i = 0; i < sources.length;) {
            unchecked {
                _setupRole(TRUSTED_SOURCE_ROLE, sources[i]);
                ++i;
            }
        }
        if (enableInitialization)
            _setupRole(INITIALIZER_ROLE, msg.sender);
    }

    // A handy utility allowing the deployer to setup initial prices (only once)
    function setupInitialPrices(address[] calldata sources, string[] calldata symbols, uint256[] calldata prices)
        external
        onlyRole(INITIALIZER_ROLE)
    {
        // Only allow one (symbol, price) per source
        require(sources.length == symbols.length && symbols.length == prices.length);
        for (uint256 i = 0; i < sources.length;) {
            unchecked {
                _setPrice(sources[i], symbols[i], prices[i]);
                ++i;
            }
        }
        renounceRole(INITIALIZER_ROLE, msg.sender);
    }

    function postPrice(string calldata symbol, uint256 newPrice) external onlyRole(TRUSTED_SOURCE_ROLE) {
        _setPrice(msg.sender, symbol, newPrice);
    }

    function getMedianPrice(string calldata symbol) external view returns (uint256) {
        return _computeMedianPrice(symbol);
    }

    function getAllPricesForSymbol(string memory symbol) public view returns (uint256[] memory prices) {
        uint256 numberOfSources = getRoleMemberCount(TRUSTED_SOURCE_ROLE);
        prices = new uint256[](numberOfSources);
        for (uint256 i = 0; i < numberOfSources;) {
            address source = getRoleMember(TRUSTED_SOURCE_ROLE, i);
            prices[i] = getPriceBySource(symbol, source);
            unchecked { ++i; }
        }
    }

    function getPriceBySource(string memory symbol, address source) public view returns (uint256) {
        return _pricesBySource[source][symbol];
    }

    function _setPrice(address source, string memory symbol, uint256 newPrice) private {
        uint256 oldPrice = _pricesBySource[source][symbol];
        _pricesBySource[source][symbol] = newPrice;
        emit UpdatedPrice(source, symbol, oldPrice, newPrice);
    }

    function _computeMedianPrice(string memory symbol) private view returns (uint256) {
        uint256[] memory prices = getAllPricesForSymbol(symbol);
        LibSort.insertionSort(prices);
        if (prices.length % 2 == 0) {
            uint256 leftPrice = prices[(prices.length / 2) - 1];
            uint256 rightPrice = prices[prices.length / 2];
            return (leftPrice + rightPrice) / 2;
        } else {
            return prices[prices.length / 2];
        }
    }
}
