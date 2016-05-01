args <- commandArgs(trailingOnly = TRUE)

df_d <- read.csv(args[1], header=F, sep=",");
names(df_d) <- c("Thread", "Start", "End", "Duration", "State");
df_d$Simulator <- "dimemas";

df_s <- read.csv(args[2], header=FALSE, sep=",");
names(df_s) <- c("Thread", "Start", "End", "Duration", "State");
df_s$Simulator <- "simgrid";

df <- rbind(df_d, df_s);

library(ggplot2);
png(filename="plot.png")
ggplot(df, aes(x=Start, y=factor(Thread), color=State)) +
   theme_bw() +
   geom_segment (aes(xend=End, yend=factor(Thread)), size=4) +
   facet_wrap(~Simulator, ncol=1);
dev.off()
