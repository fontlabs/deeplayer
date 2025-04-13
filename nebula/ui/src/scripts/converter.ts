const Converter = {
  toMoney(val: number | undefined): string {
    if (val === undefined) return "•••";

    return Intl.NumberFormat("en-US", {
      notation: "compact",
      compactDisplay: "short",
      maximumFractionDigits: 6,
    }).format(val);
  },

  format(val: number | undefined): string {
    if (val === undefined) return "•••";

    return Intl.NumberFormat("en-US", {
      maximumFractionDigits: 6,
    }).format(val);
  },

  trimAddress(val: string, pad: number = 4): string {
    return (
      val.substring(0, pad) +
      "..." +
      val.substring(val.length - pad, val.length)
    );
  },
};

export { Converter };
