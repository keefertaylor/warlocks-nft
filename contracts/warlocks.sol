//SPDX-License-Identifier: MIT
//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)

pragma solidity ^0.8.0;

/*
.・。.・゜✭・.・✫・゜・。..・。.・゜✭・.・✫・゜・。.✭・.・✫・゜・。..・✫・゜・。.・。.・゜✭・.・✫・゜・。..・。.・゜✭・.・✫・゜・。.✭・.・✫・゜・。..・✫・゜・。

  (`\ .-') /`   ('-.      _  .-')                                       .-. .-')     .-')    
   `.( OO ),'  ( OO ).-. ( \( -O )                                      \  ( OO )   ( OO ).  
,--./  .--.    / . --. /  ,------.   ,--.       .-'),-----.    .-----.  ,--. ,--.  (_)---\_) 
|      |  |    | \-.  \   |   /`. '  |  |.-')  ( OO'  .-.  '  '  .--./  |  .'   /  /    _ |  
|  |   |  |, .-'-'  |  |  |  /  | |  |  | OO ) /   |  | |  |  |  |('-.  |      /,  \  :` `.  
|  |.'.|  |_) \| |_.'  |  |  |_.' |  |  |`-' | \_) |  |\|  | /_) |OO  ) |     ' _)  '..`''.) 
|         |    |  .-.  |  |  .  '.' (|  '---.'   \ |  | |  | ||  |`-'|  |  .   \   .-._)   \ 
|   ,'.   |    |  | |  |  |  |\  \   |      |     `'  '-'  '(_'  '--'\  |  |\   \  \       / 
'--'   '--'    `--' `--'  `--' '--'  `------'       `-----'    `-----'  `--' '--'   `-----'  

.・。.・゜✭・.・✫・゜・。..・。.・゜✭・.・✫・゜・。.✭・.・✫・゜・。..・✫・゜・。.・。.・゜✭・.・✫・゜・。..・。.・゜✭・.・✫・゜・。.✭・.・✫・゜・。..・✫・゜・。
*/

// TODOs
// - Gnosis safe
// - Hardcode addresses
// - Allow price updates

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract CryptoCovmen is ERC721, IERC2981, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private tokenCounter;

    // TODO(keefertaylor): remove 
    string private baseURI;
    address private openSeaProxyRegistryAddress;
    bool private isOpenSeaProxyActive = true;

    uint256 public constant MAX_WARLOCKS_PER_WALLET = 99;
    uint256 public maxWarlocks;

    uint256 public publicSalePrice = 0.035 ether;

    // ============ ACCESS CONTROL/SANITY MODIFIERS ============

    modifier maxWarlocksPerWallet(uint256 numberOfTokens) {
        require(
            balanceOf(msg.sender) + numberOfTokens <= MAX_WARLOCKS_PER_WALLET,
            "Max warlocks to mint is three"
        );
        _;
    }

    modifier canMintWarlocks(uint256 numberOfTokens) {
        require(
            tokenCounter.current() + numberOfTokens <= maxWarlocks,
            "Not enough warlocks remaining to mint"
        );
        _;
    }


    modifier isCorrectPayment(uint256 price, uint256 numberOfTokens) {
        require(
            price * numberOfTokens == msg.value,
            "Incorrect ETH value sent"
        );
        _;
    }

    modifier isValidMerkleProof(bytes32[] calldata merkleProof, bytes32 root) {
        require(
            MerkleProof.verify(
                merkleProof,
                root,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "Address does not exist in list"
        );
        _;
    }

    constructor(
        address _openSeaProxyRegistryAddress,
        uint256 _maxWarlocks
    ) ERC721("Crypto Coven", "WARLOCK") {
        openSeaProxyRegistryAddress = _openSeaProxyRegistryAddress;
        maxWarlocks = _maxWarlocks;
    }

    // ============ PUBLIC FUNCTIONS FOR MINTING ============

    function mint(uint256 numberOfTokens)
        external
        payable
        nonReentrant
        isCorrectPayment(publicSalePrice, numberOfTokens)
        canMintWarlocks(numberOfTokens)
        maxWarlocksPerWallet(numberOfTokens)
    {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, nextTokenId());
        }
    }

    // ============ PUBLIC READ-ONLY FUNCTIONS ============

    function getBaseURI() external view returns (string memory) {
        return baseURI;
    }

    function getLastTokenId() external view returns (uint256) {
        return tokenCounter.current();
    }

    // ============ OWNER-ONLY ADMIN FUNCTIONS ============

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function setPrice(uint256 _newPrice) external onlyOwner {
        publicSalePrice = _newPrice;
    }

    // function to disable gasless listings for security in case
    // opensea ever shuts down or is compromised
    function setIsOpenSeaProxyActive(bool _isOpenSeaProxyActive)
        external
        onlyOwner
    {
        isOpenSeaProxyActive = _isOpenSeaProxyActive;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function withdrawTokens(IERC20 token) public onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }

    // ============ SUPPORTING FUNCTIONS ============

    function nextTokenId() private returns (uint256) {
        tokenCounter.increment();
        return tokenCounter.current();
    }

    // ============ FUNCTION OVERRIDES ============

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Override isApprovedForAll to allowlist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        // Get a reference to OpenSea's proxy registry contract by instantiating
        // the contract using the already existing address.
        ProxyRegistry proxyRegistry = ProxyRegistry(
            openSeaProxyRegistryAddress
        );
        if (
            isOpenSeaProxyActive &&
            address(proxyRegistry.proxies(owner)) == operator
        ) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Nonexistent token");

        return
            string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }

    /**
     * @dev See {IERC165-royaltyInfo}.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Nonexistent token");

        return (address(this), SafeMath.div(SafeMath.mul(salePrice, 5), 100));
    }
}

// These contract definitions are used to create a reference to the OpenSea
// ProxyRegistry contract by using the registry's address (see isApprovedForAll).
contract OwnableDelegateProxy {

}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}