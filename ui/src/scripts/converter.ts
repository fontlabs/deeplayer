const Converter = {
  toMoney(val: number | undefined): string {
    if (val === undefined) return "Nil";

    return Intl.NumberFormat("en-US", {
      notation: "compact",
      compactDisplay: "short",
      maximumFractionDigits: 2,
    }).format(val);
  },

  format(val: number | undefined): string {
    if (val === undefined) return "Nil";

    return Intl.NumberFormat("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 6,
    }).format(val);
  },

  toSUI(val: number, decimals: number = 8): bigint {
    return BigInt(0);
  },

  fromSUI(val: bigint, decimals: number = 8): number {
    return 0;
  },
};

export { Converter };
