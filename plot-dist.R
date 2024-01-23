### Plotting ML histogram for base and modbase
library(ggplot2)
options(repr.plot.width = 12, repr.plot.height = 10)

# Check if the command-line argument is provided
if (length(commandArgs(trailingOnly = TRUE)) < 2) {
  stop("Usage: Rscript plot-hist.R in.tsv out.png")
}

# Get the filename from the command-line argument
input_filename <- commandArgs(trailingOnly = TRUE)[1]
output_filename <- commandArgs(trailingOnly = TRUE)[2]
png(output_filename, width=12*400, height=12*400, res=400)

# Read data from the file
df <- read.table(input_filename, sep = "", header = TRUE)

# Plot ML distribution
ggplot(df, aes(x=bucket, y=count, fill=code)) +
  geom_bar(stat = "identity") + 
  facet_wrap(~ code, scales = "free", ncol=1) +
  scale_fill_brewer(palette = "Set1") +
  scale_x_continuous(breaks=seq(min(df$bucket)-1, max(df$bucket)+1, by=10)) +
  labs(title="ML probability distribution", y = "Counts", x = "Bucket") +
  theme_bw()

dev.off()