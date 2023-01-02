// SPDX-License-Identifier: MIT
pragma solidity >=0.4.25 <0.9.0;

import "@klaytn/contracts/KIP/token/KIP37/KIP37.sol";

contract HNFT is KIP37 {

    ///////////////////////////////
    //
    ///////////////////////////////

    struct NFTStruct {
        string nftId;
        string uri;
        string uriHash;
        string category;
        address creator;
        uint256 total;

        uint listPointer;
    }

    struct categoryStruct {
        string[] nftIds;

        uint listPointer;
    }

    struct NFTOwnerStruct {
        address owner;
        uint256 balance;
    }

    struct NFTDetailStruct {
        NFTStruct nft;
        NFTOwnerStruct[] owners;
    }

    struct NFTOwnerDetailStruct {
        NFTStruct nft;
        uint256 balance;
    }

    address private _owner;
    mapping(address => bool) private _marketAddress;

    mapping(string => NFTStruct) private _nftStructs;
    string[] private _nftKeys;

    mapping(string => categoryStruct) private _categoryStructs;
    string[] private _categoryKeys;

    mapping(string => address[]) private _ownerListByNftId;
    mapping(address => string[]) private _nftListByOwner;

    mapping(address => mapping(string => mapping(address => uint256))) private _nftApprovals;
    mapping(address => mapping(string => uint256)) private _nftApprovalsSum;
    mapping(address => mapping(address => mapping(string => mapping(string => uint256)))) private _nftApprovalsLog;

    ///////////////////////////////
    // constructor
    ///////////////////////////////

    constructor(string memory uri_) KIP37(uri_) {
        _owner = _msgSender();
    }

    modifier onlyOwner() {
        require(_msgSender() == _owner);
        _;
    }

    modifier onlyMarket() {
        require(true == _marketAddress[_msgSender()]);
        _;
    }

    ///////////////////////////////
    // view publice / external
    ///////////////////////////////

    function ExistNFT(string calldata nftId) public view returns(bool) {
        if(_nftKeys.length == 0) return false;
        return _string_equal(_nftKeys[_nftStructs[nftId].listPointer], nftId);
    }

    function GetNFTCount() external view returns(uint) {
        return _nftKeys.length;
    }

    function GetNFTDetail(string calldata nftId) external view returns(NFTDetailStruct memory) {
        NFTDetailStruct memory detail;
        detail.nft = _nftStructs[nftId];
        detail.owners = GetOwnerListByNftId(nftId);

        return detail;
    }

    function GetNFTIds(uint start, uint count) external view returns(string[] memory, uint, bool) {
        return _getPage(_nftKeys, start, count);
    }

    function GetNFTIdsWithCategory(string calldata category, uint start, uint count) external view returns(string[] memory, uint, bool) {
        return _getPage(_categoryStructs[category].nftIds, start, count);
    }

    function GetCategorys(uint start, uint count) external view returns(string[] memory, uint, bool) {
        return _getPage(_categoryKeys, start, count);
    }

    function GetOwnerListByNftId(string calldata nftId) public view returns(NFTOwnerStruct[] memory) {
        address[] memory ownerList = _ownerListByNftId[nftId];
        NFTOwnerStruct[] memory owners = new NFTOwnerStruct[](ownerList.length);

        for(uint i = 0; i < ownerList.length; ++i) {
            address owner = ownerList[i];

            NFTOwnerStruct memory nftOwner;
            nftOwner.owner = owner;
            nftOwner.balance = super.balanceOf(owner, _nftStructs[nftId].listPointer);

            owners[i] = nftOwner;
        }

        return owners;
    }

    function GetNftIdListByOwner(address owner) external view returns(string[] memory) {
        return _nftListByOwner[owner];
    }

    function GetNftDetailListByOwner(address owner) external view returns(NFTOwnerDetailStruct[] memory) {
        string[] memory nftList = _nftListByOwner[owner];
        NFTOwnerDetailStruct[] memory nftOwnerDetails = new NFTOwnerDetailStruct[](nftList.length);
        
        for(uint i = 0; i < nftList.length; ++i) {
            NFTStruct memory nft = _nftStructs[nftList[i]];

            NFTOwnerDetailStruct memory nftOwnerDetail;
            nftOwnerDetail.nft = nft;
            nftOwnerDetail.balance = super.balanceOf(owner, nft.listPointer);

            nftOwnerDetails[i] = nftOwnerDetail;
        }

        return nftOwnerDetails;
    }

    function GetApprovals(address owner, address operator, string calldata nftId) external view returns(uint256 amount) {
        return _nftApprovals[owner][nftId][operator];
    }

    function GetApprovalsLog(address owner, address operator, string calldata nftId, string calldata reason) external view returns(uint256 amount) {
        return _nftApprovalsLog[owner][operator][nftId][reason];
    }

    ///////////////////////////////
    // external
    ///////////////////////////////

    function AddMarketAddress(address marketAddress) external onlyOwner {
        _marketAddress[marketAddress] = true;

        emit eventAddMarketAddress(marketAddress);
    }

    function RemoveMarketAddress(address marketAddress) external onlyOwner {
        _marketAddress[marketAddress] = false;

        emit eventRemoveMarketAddress(marketAddress);
    }

    function CreateAndMint(string calldata nftId, string calldata uri, string calldata uriHash, string calldata category, uint256 amount, address to) external onlyMarket {
        super._mint(to, _newNFT(nftId, uri, uriHash, category, to), amount, "");

        emit eventCreateAndMint(_msgSender(), nftId, uri, uriHash, category, amount, to);
    }

    function CreateAndMintBatch(string[] calldata nftIds, string[] calldata uris, string[] calldata uriHashs, string[] calldata categorys, uint256[] calldata amounts, address to) external onlyMarket {
        require(nftIds.length == uris.length && 
            uris.length == uriHashs.length && 
            uriHashs.length == categorys.length &&
            categorys.length == amounts.length);

        uint256[] memory ids = new uint256[](nftIds.length);
        for(uint i = 0; i < nftIds.length; ++i) {
            ids[i] = _newNFT(nftIds[i], uris[i], uriHashs[i], categorys[i], to);
        }
        
        super._mintBatch(to, ids, amounts, "");

        emit eventCreateAndMintBatch(_msgSender(), nftIds, uris, uriHashs, categorys, amounts, to);
    }

    function Mint(string calldata nftId, uint256 amount, address to) external onlyMarket {
        require(true == ExistNFT(nftId));
        require(_nftStructs[nftId].creator == to);

        super._mint(to, _nftStructs[nftId].listPointer, amount, "");

        emit eventMint(_msgSender(), nftId, amount, to);
    }

    function MintBatch(string[] calldata nftIds, uint256[] calldata amounts, address to) external onlyMarket {
        require(nftIds.length == amounts.length);

        uint256[] memory ids = new uint256[](nftIds.length);
        for(uint i = 0; i < nftIds.length; ++i) {
            string calldata nftId = nftIds[i];
            require(true == ExistNFT(nftId));
            require(_nftStructs[nftId].creator == to);

            ids[i] = _nftStructs[nftId].listPointer;
        }

        super._mintBatch(to, ids, amounts, "");

        emit eventMintBatch(_msgSender(), nftIds, amounts, to);
    }

    function TransferFrom(address from, address to, string calldata nftId, uint256 amount) external {
        require(true == ExistNFT(nftId));

        super.safeTransferFrom(from, to, _nftStructs[nftId].listPointer, amount, "");

        emit eventTransferFrom(_msgSender(), from, to, nftId, amount);
    }

    function BatchTransferFrom(address from, address to, string[] calldata nftIds, uint256[] calldata amounts) external {
        uint256[] memory ids = _getIds(nftIds);

        super.safeBatchTransferFrom(from, to, ids, amounts, "");

        emit eventBatchTransferFrom(_msgSender(), from, to, nftIds, amounts);
    }

    function TransferApproved(address from, address to, string calldata nftId, uint256 amount) external {
        require(true == ExistNFT(nftId));

        super._safeTransferFrom(from, to, _nftStructs[nftId].listPointer, amount, "TransferApproved");

        emit eventTransferApproved(_msgSender(), from, to, nftId, amount);
    }

    function BatchTransferApproved(address from, address to, string[] calldata nftIds, uint256[] calldata amounts) external {
        uint256[] memory ids = _getIds(nftIds);

        super._safeBatchTransferFrom(from, to, ids, amounts, "TransferApproved");

        emit eventBatchTransferApproved(_msgSender(), from, to, nftIds, amounts);
    }

    function ApprovalAdd(address operator, string calldata nftId, string calldata reason, uint256 amount) external {
        _ApprovalAdd(_msgSender(), operator, nftId, reason, amount);

        emit eventApprovalAdd(_msgSender(), operator, nftId, reason, amount);
    }

    function BatchApprovalAdd(address operator, string[] calldata nftIds, string[] calldata reasons, uint256[] calldata amounts) external {
        require(nftIds.length == amounts.length &&
            amounts.length == reasons.length);

        for(uint i = 0; i < nftIds.length; ++i) {
            _ApprovalAdd(_msgSender(), operator, nftIds[i], reasons[i], amounts[i]);
        }

        emit eventBatchApprovalAdd(_msgSender(), operator, nftIds, reasons, amounts);
    }

    function ApprovalSub(address owner, address operator, string calldata nftId, uint256 amount) external {
        if(true == _marketAddress[operator]) {
            require(true == _marketAddress[_msgSender()]);
        } else {
            require(_msgSender() == owner);
        }

        _ApprovalSub(owner, operator, nftId, amount);

        emit eventApprovalSub(_msgSender(), owner, operator, nftId, amount);
    }

    function BatchApprovalSub(address owner, address operator, string[] calldata nftIds, uint256[] calldata amounts) external {
        require(nftIds.length == amounts.length);

        if(true == _marketAddress[operator]) {
            require(true == _marketAddress[_msgSender()]);
        } else {
            require(_msgSender() == owner);
        }

        for(uint i = 0; i < nftIds.length; ++i) {
            _ApprovalSub(owner, operator, nftIds[i], amounts[i]);
        }

        emit eventBatchApprovalSub(_msgSender(), owner, operator, nftIds, amounts);
    }

    function ApprovalSubMarket(address owner, address operator, string calldata nftId, string calldata reason, uint256 amount) external onlyMarket {
        _ApprovalSubMarket(owner, operator, nftId, reason, amount);

        emit eventApprovalSubMarket(_msgSender(), owner, operator, nftId, reason, amount);
    }

    function BatchApprovalSubMarket(address owner, address operator, string[] calldata nftIds, string[] calldata reasons, uint256[] calldata amounts) external onlyMarket {
        require(nftIds.length == amounts.length &&
            amounts.length == reasons.length);

        for(uint i = 0; i < nftIds.length; ++i) {
            _ApprovalSubMarket(owner, operator, nftIds[i], reasons[i], amounts[i]);
        }

        emit eventBatchApprovalSubMarket(_msgSender(), owner, operator, nftIds, reasons, amounts);
    }

    ///////////////////////////////
    // override
    ///////////////////////////////

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        for(uint i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            for(uint j = i+1; j < ids.length; ++j) {
                if(id == ids[j]) {
                    revert();
                }
            }

            string memory nftId = _nftKeys[id];
            if(address(0) == from) {
                // isMint
                _nftStructs[nftId].total += amounts[i];

            } else if (address(0) == to) {
                // isBurn
                _nftStructs[nftId].total -= amounts[i];

            } else {
                // isTransfer
                if(_string_equal(string(data), "TransferApproved")) {
                    _ApprovalSub(from, operator, nftId, amounts[i]);

                } else {
                    require((super.balanceOf(from, id) - _nftApprovalsSum[from][nftId]) >= amounts[i]);
                }
            }
        }
    }

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        for(uint i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            string memory nftId = _nftKeys[id];

            if(address(0) == from) {
                // isMint
                _addEachList(to, nftId);

            } else if (address(0) == to) {
                // isBurn
                _removeEachList(from, id);

            } else {
                // isTransfer
                _addEachList(to, nftId);
                _removeEachList(from, id);
            }
        }
    }

    ///////////////////////////////
    // private
    ///////////////////////////////

    function _ApprovalAdd(address owner, address operator, string calldata nftId, string calldata reason, uint256 amount) private {
        require(true == ExistNFT(nftId));
        require((super.balanceOf(owner, _nftStructs[nftId].listPointer) - _nftApprovalsSum[owner][nftId]) >= amount);

        _nftApprovals[owner][nftId][operator] += amount;
        _nftApprovalsSum[owner][nftId] += amount;

        _nftApprovalsLog[owner][operator][nftId][reason] += amount;
    }

    function _ApprovalSub(address owner, address operator, string memory nftId, uint256 amount) private {
        uint256 currentApprove = _nftApprovals[owner][nftId][operator];
        uint256 currentSum = _nftApprovalsSum[owner][nftId];
        require(currentApprove >= amount);
        require(currentSum >= amount);

        unchecked {
            if(currentApprove == amount) {
                delete _nftApprovals[owner][nftId][operator];
            } else {
                _nftApprovals[owner][nftId][operator] -= amount;
            }

            if(currentSum == amount) {
                delete _nftApprovalsSum[owner][nftId];
            } else {
                _nftApprovalsSum[owner][nftId] -= amount;
            }
        }
    }

    function _ApprovalSubMarket(address owner, address operator, string calldata nftId, string calldata reason, uint256 amount) private {
        require(true == _marketAddress[operator]);

        _ApprovalSub(owner, operator, nftId, amount);

        uint256 current = _nftApprovalsLog[owner][operator][nftId][reason];
        require(current >= amount);

        unchecked {
            if(current == amount) {
                delete  _nftApprovalsLog[owner][operator][nftId][reason];
            } else {
                 _nftApprovalsLog[owner][operator][nftId][reason] -= amount;
            }
        }
    }

    function _setCategory(string calldata nftId, string calldata category) private {
        if(false == _existCategory(category)) {
            _categoryKeys.push(category);
            _categoryStructs[category].listPointer = _categoryKeys.length - 1;
        }

        _categoryStructs[category].nftIds.push(nftId);
    }

    function _newNFT(string calldata nftId, string calldata uri, string calldata uriHash, string calldata category, address creator) private returns(uint) {
        require(false == ExistNFT(nftId));
        _setCategory(nftId, category);

        _nftKeys.push(nftId);

        NFTStruct storage nftStruct = _nftStructs[nftId];
        nftStruct.nftId = nftId;
        nftStruct.uri = uri;
        nftStruct.uriHash = uriHash;
        nftStruct.category = category;
        nftStruct.creator = creator;
        nftStruct.listPointer = _nftKeys.length - 1;

        return _nftKeys.length - 1;
    }

    function _addEachList(address to, string memory nftId) private {
        bool isHave = false;
        address[] storage ownerList = _ownerListByNftId[nftId];
        for(uint i = 0; i < ownerList.length; ++i) {
            if(ownerList[i] == to) {
                isHave = true;
                break;
            }
        }

        if(false == isHave) {
            ownerList.push(to);
        }

        isHave = false;
        string[] storage nftList = _nftListByOwner[to];
        for(uint i = 0; i < nftList.length; ++i) {
            if(_string_equal(nftList[i], nftId)) {
                isHave = true;
                break;
            }
        }

        if(false == isHave) {
            nftList.push(nftId);
        }
    }

    function _removeEachList(address from, uint256 id) private {
        if(0 != super.balanceOf(from, id)) {
            return;
        }

        string memory nftId = _nftKeys[id];
        address[] storage ownerList = _ownerListByNftId[nftId];
        uint lastIndex = ownerList.length - 1;
        for(uint i = 0; i < lastIndex; ++i) {
            if(ownerList[i] == from) {
                ownerList[i] = ownerList[lastIndex];
                break;
            }
        }
        ownerList.pop();

        string[] storage nftList = _nftListByOwner[from];
        lastIndex = nftList.length - 1;
        for(uint i = 0; i < lastIndex; ++i) {
            if(_string_equal(nftList[i], nftId)) {
                nftList[i] = nftList[lastIndex];
                break;
            }
        }
        nftList.pop();
    }

    ///////////////////////////////
    // view private
    ///////////////////////////////

    function _existCategory(string calldata category) private view returns(bool) {
        if(_categoryKeys.length == 0) return false;
        return _string_equal(_categoryKeys[_categoryStructs[category].listPointer], category);
    }

    function _getIds(string[] calldata nftIds) private view returns(uint256[] memory) {
        uint256[] memory ids = new uint256[](nftIds.length);
        
        for(uint i = 0; i < nftIds.length; ++i) {
            string calldata nftId = nftIds[i];
            require(true == ExistNFT(nftId));

            ids[i] = _nftStructs[nftId].listPointer;
        }

        return ids;
    }

    ///////////////////////////////
    // pure private
    ///////////////////////////////

    function _getPage(string[] memory list, uint start, uint count) private pure returns(string[] memory, uint, bool) {
        require(0 < count);

        uint total = list.length;
        if(0 == total) {
            return (new string[](0), total, false);
        }

        uint lastIndex = start + count - 1;
        bool next = lastIndex < (total - 1);
        if(false == next) {
            lastIndex = total - 1;
        }

        if(lastIndex < start) {
            return (new string[](0), total, false);
        }

        uint newCount = lastIndex - start + 1;
        string[] memory newList = new string[](newCount);
        for(uint i = 0; i < newCount; ++i) {
            newList[i] = list[i+start];
        }

        return (newList, total, next);
    }

    function _string_equal(string memory org, string memory dst) private pure returns(bool) {
        return keccak256(abi.encodePacked(org)) == keccak256(abi.encodePacked(dst));
    }

    ///////////////////////////////
    // event
    ///////////////////////////////
    event eventAddMarketAddress(address marketAddress);
    event eventRemoveMarketAddress(address marketAddress);

    event eventCreateAndMint(address indexed operator, string nftId, string uri, string uriHash, string category, uint256 amount, address to);
    event eventCreateAndMintBatch(address indexed operator, string[] nftIds, string[] uris, string[] uriHashs, string[] categorys, uint256[] amounts, address to);
    event eventMint(address indexed operator, string nftId, uint256 amount, address to);
    event eventMintBatch(address indexed operator, string[] nftIds, uint256[] amounts, address to);

    event eventTransferFrom(address indexed operator, address indexed from, address indexed to, string nftId, uint256 amount);
    event eventBatchTransferFrom(address indexed operator, address indexed from, address indexed to, string[] nftIds, uint256[] amounts);
    event eventTransferApproved(address indexed operator, address indexed from, address indexed to, string nftId, uint256 amount);
    event eventBatchTransferApproved(address indexed operator, address indexed from, address indexed to, string[] nftIds, uint256[] amounts);

    event eventApprovalAdd(address indexed owner, address indexed operator, string nftId, string reason, uint256 amount);
    event eventBatchApprovalAdd(address indexed owner, address indexed operator, string[] nftIds, string[] reasons, uint256[] amounts);
    event eventApprovalSub(address indexed msgSender, address indexed owner, address indexed operator, string nftId, uint256 amount);
    event eventBatchApprovalSub(address indexed msgSender, address indexed owner, address indexed operator, string[] nftIds, uint256[] amounts);
    event eventApprovalSubMarket(address indexed msgSender, address indexed owner, address indexed operator, string nftId, string reason, uint256 amount);
    event eventBatchApprovalSubMarket(address indexed msgSender, address indexed owner, address indexed operator, string[] nftIds, string[] reasons, uint256[] amounts);
}
