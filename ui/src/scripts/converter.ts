const Converter = {
  toMoney(val: number | undefined): string {
    if (val === undefined) return "•••";

    return Intl.NumberFormat("en-US", {
      notation: "compact",
      compactDisplay: "short",
      maximumFractionDigits: 2,
    }).format(val);
  },

  format(val: number | undefined): string {
    if (val === undefined) return "•••";

    return Intl.NumberFormat("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 6,
    }).format(val);
  },

  toSUI(val: number | undefined, decimals: number = 9): bigint | undefined {
    if (val === undefined) return val;
    return BigInt(Math.round(val * 10 ** decimals));
  },

  fromSUI(val: bigint | undefined, decimals: number = 9): number | undefined {
    if (val === undefined) return val;
    return Number(val) / 10 ** decimals;
  },
};

export { Converter };
