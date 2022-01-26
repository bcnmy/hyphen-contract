function getLocaleString(amount: number) {
    return amount.toLocaleString('fullwide', {useGrouping:false});
}

module.exports = {
    getLocaleString
}