"use strict";

/* -- THEME ------------------------------------------------- */
function themePrefix(theme) { return `--${theme}-`; }
const actualPrefix = themePrefix("actual");
const THEME_NAME   = "site-theme";
const THEMES       = ["dark", "light"];
const THEME_FIELDS = [];
let selectedTheme  = null;

function getTheme(safe = true) {
    const theme = localStorage.getItem(THEME_NAME) ?? null;
    if (theme != null) {
        for (const THEME of THEMES) {
            if (theme === THEME) return theme;
        }
    }
    if (safe) return THEMES[0];
    return null;
}

function setTheme(theme, safe = true) {
    if (selectedTheme === theme) return;
    let found = false;
    for (const THEME of THEMES) {
        if (theme === THEME) {
            found = true;
            break;
        }
    }
    if (!found) {
        if (!safe) return false;
        theme = THEMES[0];
    }
    localStorage.setItem(THEME_NAME, theme);
    updateTheme();
    return true;
}

function updateTheme() {
    const theme = getTheme();
    if (theme === selectedTheme) return;
    const prefix = themePrefix(theme);
    const style  = document.documentElement.style;
    for (const field of THEME_FIELDS) {
        const fieldName = `${actualPrefix}${field}`;
        style.setProperty(fieldName, `var(${prefix}${field})`);
    }
    selectedTheme = theme;
}

function prepareTheme() {
    for (const sheet of document.styleSheets) {
        let rules;
        try { rules = sheet.cssRules; } catch (e) { continue; }
        for (const rule of rules) {
            if (!rule.style) continue;
            for (const name of rule.style) {
                if (!name.startsWith(actualPrefix)) continue;
                const field = name.substr(actualPrefix.length);
                if (!THEME_FIELDS.includes(field)) THEME_FIELDS.push(field);
            }
        }
    }
}

function toggleTheme() {
    const theme = getTheme();
    setTheme(theme === "light" ? "dark" : "light");
}

/* -- ABIs (minimal) ---------------------------------------- */
const ERC20_VOTES_ABI = [
    "function balanceOf(address) view returns (uint256)",
    "function getVotes(address) view returns (uint256)",
    "function delegates(address) view returns (address)",
    "function delegate(address delegatee)",
    "function decimals() view returns (uint8)",
    "function symbol() view returns (string)"
];

const GOVERNOR_ABI = [
    "function state(uint256 proposalId) view returns (uint8)",
    "function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)",
    "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
    "function hasVoted(uint256 proposalId, address account) view returns (bool)",
    "function proposalDescription(uint256 proposalId) view returns (string)"
];

const PROPOSAL_STATES = [
    "PENDING", "ACTIVE", "CANCELLED", "DEFEATED",
    "SUCCEEDED", "QUEUED", "EXPIRED", "EXECUTED"
];

const ACTIVE_STATES = new Set([1]); // only Active allows voting

/* -- APP STATE --------------------------------------------- */
let provider  = null;
let signer    = null;
let account   = null;
let tokenContract    = null;
let governorContract = null;
let tokenDecimals    = 18;

/* -- LOG --------------------------------------------------- */
function log(msg, type = "info") {
    const now = new Date();
    const ts  = `${String(now.getHours()).padStart(2,"0")}:${String(now.getMinutes()).padStart(2,"0")}:${String(now.getSeconds()).padStart(2,"0")}`;
    const cls = type === "ok" ? "log-ok" : type === "err" ? "log-err" : "log-info";
    const entry = $(`<div class="log-entry"><span class="log-time">${ts}</span><span class="${cls}">${msg}</span></div>`);
    $("#tx-log").append(entry);
    $("#tx-log").scrollTop($("#tx-log")[0].scrollHeight);
}

/* -- CONNECT WALLET ---------------------------------------- */
async function connectWallet() {
    if (typeof window.ethereum === "undefined") {
        log("MetaMask not detected. Install MetaMask to continue.", "err");
        return;
    }
    try {
        provider = new ethers.BrowserProvider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        signer  = await provider.getSigner();
        account = await signer.getAddress();

        const network = await provider.getNetwork();
        $("#network-badge")
            .text(`// ${network.name.toUpperCase()} #${network.chainId}`)
            .addClass("connected");

        $("#btn-connect").text("CONNECTED").prop("disabled", true);
        $("#wallet-bar, #app-main").removeClass("hidden");

        $("#wb-address").text(shortAddr(account));
        log(`Wallet connected: ${account}`, "ok");

        // Listen for account/network changes
        window.ethereum.on("accountsChanged", () => location.reload());
        window.ethereum.on("chainChanged",    () => location.reload());
    } catch (e) {
        log(`Connection failed: ${e.message}`, "err");
    }
}

/* -- LOAD CONTRACTS ---------------------------------------- */
async function loadContracts() {
    const tokenAddr    = $("#input-token").val().trim();
    const governorAddr = $("#input-governor").val().trim();

    if (!ethers.isAddress(tokenAddr) || !ethers.isAddress(governorAddr)) {
        log("Invalid contract address(es).", "err");
        return;
    }
    try {
        tokenContract    = new ethers.Contract(tokenAddr, ERC20_VOTES_ABI, signer);
        governorContract = new ethers.Contract(governorAddr, GOVERNOR_ABI, signer);

         const code = await provider.getCode(tokenAddr);
         if (code === "0x") {
             throw new Error(`No contract at ${tokenAddr} on this network`);
         }
         const govCode = await provider.getCode(governorAddr);
         if (govCode === "0x") {
             throw new Error(`No contract at ${governorAddr} on this network`);
         }

        try {
            tokenDecimals = Number(await tokenContract.decimals());
        } catch {
            tokenDecimals = 18;
            log("decimals() failed - assuming 18", "info");
        }

        let symbol = "TOKEN";
        try {
            symbol = await tokenContract.symbol();
        } catch {
            log("symbol() failed - using 'TOKEN'", "info"); 
        }

        log(`Token: ${symbol} @ ${shortAddr(tokenAddr)}`, "ok");
        log(`Governor @ ${shortAddr(governorAddr)}`, "ok");

        await refreshWalletInfo();
    } catch (e) {
        log(`Load contracts failed: ${e.message}`, "err");
    }
}

/* -- WALLET INFO ------------------------------------------- */
async function refreshWalletInfo() {
    if (!tokenContract || !account) return;
    try {
        const [bal, votes, delegate] = await Promise.all([
            tokenContract.balanceOf(account),
            tokenContract.getVotes(account),
            tokenContract.delegates(account)
        ]);
        const fmt = (v) => Number(ethers.formatUnits(v, tokenDecimals)).toLocaleString(undefined, { maximumFractionDigits: 4 });
        $("#wb-balance").text(fmt(bal));
        $("#wb-votes").text(fmt(votes));
        $("#wb-delegate").text(delegate === account ? "SELF" : shortAddr(delegate));
    } catch (e) {
        log(`Refresh wallet info failed: ${e.message}`, "err");
    }
}

/* -- DELEGATE ---------------------------------------------- */
async function delegate() {
    if (!tokenContract) { log("Load contracts first.", "err"); return; }
    let addr = $("#input-delegate").val().trim();
    if (addr.toUpperCase() === "SELF") addr = account;
    if (!ethers.isAddress(addr)) { log("Invalid delegate address.", "err"); return; }

    const $status = $("#delegate-status");
    $status.text("Broadcasting tx...").removeClass("error hidden");
    try {
        const tx = await tokenContract.delegate(addr);
        log(`Delegate tx: ${tx.hash}`, "info");
        $status.text(`Waiting for confirmation...`);
        await tx.wait();
        log(`Delegated to ${addr}`, "ok");
        $status.text(`✓ Delegated to ${addr === account ? "self" : shortAddr(addr)}`);
        await refreshWalletInfo();
    } catch (e) {
        log(`Delegate failed: ${e.message}`, "err");
        $status.text(`✗ ${e.reason || e.message}`).addClass("error");
    }
}

/* -- FETCH PROPOSALS --------------------------------------- */
async function fetchProposals() {
    if (!governorContract) { log("Load contracts first.", "err"); return; }

    const raw = $("#input-proposals").val().trim();
    if (!raw) { log("Enter at least one proposal ID.", "err"); return; }

    const ids = raw.split("\n").map(l => l.trim()).filter(Boolean);
    $("#proposals-list").empty();
    log(`Fetching ${ids.length} proposal(s)...`, "info");

    for (const id of ids) {
        try {
            const bid = BigInt(id);
            await renderProposal(bid);
        } catch (e) {
            log(`Proposal ${id}: ${e.message}`, "err");
        }
    }
}

async function renderProposal(proposalId) {
    const [stateNum, votes, voted] = await Promise.all([
        governorContract.state(proposalId),
        governorContract.proposalVotes(proposalId),
        account ? governorContract.hasVoted(proposalId, account) : Promise.resolve(false)
    ]);

    const stateName  = PROPOSAL_STATES[stateNum] ?? "UNKNOWN";
    const stateClass = `state-${stateName.toLowerCase()}`;
    const isActive   = ACTIVE_STATES.has(Number(stateNum));

    // Clone template
    const tpl  = document.getElementById("tpl-proposal").content.cloneNode(true);
    const $card = $(tpl).find(".proposal-card");
    // (template clones a fragment; grab the card)
    const $frag = $(document.importNode(document.getElementById("tpl-proposal").content, true));
    const $c    = $frag.find(".proposal-card");

    $c.attr("data-id", proposalId.toString());
    $c.find(".prop-id").text(`ID: ${proposalId.toString().slice(0, 12)}...`);
    $c.find(".prop-state-badge").text(stateName).addClass(stateClass);
    $c.find(".prop-desc").text(`Proposal #${proposalId.toString().slice(-8)}`);

    // Votes
    const forV     = Number(ethers.formatUnits(votes[1], tokenDecimals));
    const againstV = Number(ethers.formatUnits(votes[0], tokenDecimals));
    const abstainV = Number(ethers.formatUnits(votes[2], tokenDecimals));
    const total    = forV + againstV + abstainV || 1;

    $c.find(".prop-results").removeClass("hidden");
    $c.find(".vb-for").css("width",     `${(forV / total * 100).toFixed(1)}%`);
    $c.find(".vb-against").css("width", `${(againstV / total * 100).toFixed(1)}%`);
    $c.find(".vb-abstain").css("width", `${(abstainV / total * 100).toFixed(1)}%`);
    $c.find(".vf-val").text(fmt(forV));
    $c.find(".va-val").text(fmt(againstV));
    $c.find(".vab-val").text(fmt(abstainV));

    // Vote actions
    if (isActive && !voted) {
        $c.find(".prop-actions").removeClass("hidden");
        $c.find(".btn-vote").on("click", async function () {
            const support = parseInt($(this).attr("data-support"));
            await castVote(proposalId, support, $c);
        });
    } else if (voted) {
        $c.find(".prop-voted-badge").removeClass("hidden");
    }

    $("#proposals-list").append($frag);
    log(`Loaded proposal ${proposalId.toString().slice(-8)}: ${stateName}`, "ok");
}

/* -- CAST VOTE --------------------------------------------- */
async function castVote(proposalId, support, $card) {
    if (!governorContract) return;
    $card.find(".btn-vote").prop("disabled", true);
    const label = ["AGAINST", "FOR", "ABSTAIN"][support];
    log(`Casting vote: ${label} on proposal ...${proposalId.toString().slice(-8)}`, "info");
    try {
        const tx = await governorContract.castVote(proposalId, support);
        log(`Vote tx: ${tx.hash}`, "info");
        await tx.wait();
        log(`Vote confirmed: ${label}`, "ok");
        $card.find(".prop-actions").addClass("hidden");
        $card.find(".prop-voted-badge").removeClass("hidden");
    } catch (e) {
        log(`Vote failed: ${e.reason || e.message}`, "err");
        $card.find(".btn-vote").prop("disabled", false);
    }
}

/* -- HELPERS ----------------------------------------------- */
function shortAddr(addr) {
    if (!addr || addr.length < 10) return addr;
    return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

function fmt(n) {
    if (n >= 1e6)  return `${(n / 1e6).toFixed(2)}M`;
    if (n >= 1e3)  return `${(n / 1e3).toFixed(2)}K`;
    return n.toFixed(2);
}

/* -- INIT -------------------------------------------------- */
$(document).ready(function () {
    prepareTheme();
    updateTheme();
    
    $("#btn-connect").on("click", connectWallet);
    $("#btn-theme").on("click", toggleTheme);
    $("#btn-load").on("click", loadContracts);
    $("#btn-delegate").on("click", delegate);
    $("#btn-self-delegate").on("click", () => {
        if (account) $("#input-delegate").val(account);
    });
    $("#btn-load-proposals").on("click", fetchProposals);
    $("#btn-refresh").on("click", fetchProposals);
    $("#btn-clear-log").on("click", () => $("#tx-log").empty());

    log("DAO Governance interface ready.", "info");
    log("Connect your wallet to begin.", "info");
});
