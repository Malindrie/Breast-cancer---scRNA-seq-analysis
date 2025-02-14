# Analysis code for the scRNA-seq data in the three conditions
# All analysis was performed using Seurat

library(Seurat)

# Read 10x files from CellRanger output to R environment for each of the three conditions
GPx2KD_mat <- Read10X(data.dir = "./GPx2KD_sam5/outs/filtered_feature_bc_matrix")
GPxLngM_mat <- Read10X(data.dir = "./GPxLngm_sam6/outs/filtered_feature_bc_matrix")
NTtumor_mat <- Read10X(data.dir = "./NTtumor_sam7/outs/filtered_feature_bc_matrix")

# Set up Seurat objects for each condition GPx2KD, GPxLngM, NTtumor
GPx2KD_01 <- CreateSeuratObject(counts = GPx2KD_mat,project = "GPx2KD")
GPxLngM_01 <- CreateSeuratObject(counts = GPxLngM_mat,project = "GPxLngM")
NTtumor_01 <- CreateSeuratObject(counts = NTtumor_mat,project = "NTtumor")

# Perform quality control
# Check for mitochondrial genes
GPx2KD_01[["percent.mt"]] <- PercentageFeatureSet(GPx2KD_01, pattern = "^mt-")
GPxLngM_01[["percent.mt"]] <- PercentageFeatureSet(GPxLngM_01, pattern = "^mt-")
NTtumor_01[["percent.mt"]] <- PercentageFeatureSet(NTtumor_01, pattern = "^mt-")

# Vln plots of features/counts/mitochondrial genes
VlnPlot(GPx2KD_01, features = c("nFeature_RNA", "nCount_RNA", "percent.mt"), ncol = 3)
VlnPlot(GPxLngM_01, features = c("nFeature_RNA", "nCount_RNA", "percent.mt"), ncol = 3)
VlnPlot(NTtumor_01, features = c("nFeature_RNA", "nCount_RNA", "percent.mt"), ncol = 3)

# Combined Feature plots
p1_Gpx2KD_01 <- FeatureScatter(GPx2KD_01, feature1 = "nCount_RNA", feature2 = "percent.mt")
p2_Gpx2KD_01 <- FeatureScatter(GPx2KD_01, feature1 = "nCount_RNA", feature2 = "nFeature_RNA")
CombinePlots(plots = list(p1_Gpx2KD_01, p2_Gpx2KD_01))

p1_LngM_01 <- FeatureScatter(GPxLngM_01, feature1 = "nCount_RNA", feature2 = "percent.mt")
p2_LngM_01 <- FeatureScatter(GPxLngM_01, feature1 = "nCount_RNA", feature2 = "nFeature_RNA")
CombinePlots(plots = list(p1_LngM_01, p2_LngM_01))

p1_Nttum_01 <- FeatureScatter(NTtumor_01, feature1 = "nCount_RNA", feature2 = "percent.mt")
p2_Nttum_01 <- FeatureScatter(NTtumor_01, feature1 = "nCount_RNA", feature2 = "nFeature_RNA")
CombinePlots(plots = list(p1_Nttum_01, p2_Nttum_01))

# Filter for outliers
GPx2KD_01 <- subset(GPx2KD_01, subset = nFeature_RNA > 200 & nFeature_RNA < 4500 & percent.mt < 10)
GPxLngM_01 <- subset(GPxLngM_01, subset = nFeature_RNA > 200 & nFeature_RNA < 4500 & percent.mt < 10)
NTtumor_01 <- subset(NTtumor_01, subset = nFeature_RNA > 200 & nFeature_RNA < 4500 & percent.mt < 10)

# Create Condition Variable
GPx2KD_01$stim <- "Gpx2KD"
GPxLngM_01$stim <- "GPxLngM"
NTtumor_01$stim <- "NTtumor"

# Normalization, scaling and selecting highly variable genes
# Perform SCTransform
GPx2KD_01 <- SCTransform(GPx2KD_01, verbose = FALSE)
GPxLngM_01 <- SCTransform(GPxLngM_01, verbose = FALSE)
NTtumor_01 <- SCTransform(NTtumor_01, verbose = FALSE)

# Here after analysis is performed only between Gpx2KD & Nttumor
# Perform integration for only Gpx2KD & Nttumor
# Select Integration Features and calculate Pearson residuals
hazen.features <- SelectIntegrationFeatures(object.list = list(GPx2KD_01,NTtumor_01), nfeatures = 3000)

options(future.globals.maxSize= 2.19*1024*1024^2)

hazen.list <- PrepSCTIntegration(object.list = list(GPx2KD_01,NTtumor_01), anchor.features = hazen.features, verbose = FALSE)

# Identify anchors and integrate the datasets
hazen.anchors <- FindIntegrationAnchors(object.list = hazen.list, normalization.method = "SCT",
                                        anchor.features = hazen.features, verbose = FALSE)
hazen.integrated <- IntegrateData(anchorset = hazen.anchors, normalization.method = "SCT",verbose = FALSE)

# Run the standard workflow for visualization and clustering
hazen.combined <- RunPCA(hazen.integrated, npcs = 50, verbose = FALSE)
ElbowPlot(hazen.combined , ndims = 50)
hazen.combined <- RunUMAP(hazen.combined, reduction = "pca", dims = 1:30)
hazen.combined <- FindNeighbors(hazen.combined, reduction = "pca", dims = 1:30)

# Clustering
# Trying multiple clustering parameters
hazen.clusters1 <- FindClusters(hazen.combined, resolution = seq(0.1,0.8,0.1))
hazen.clusters2 <- FindClusters(hazen.combined, resolution = seq(0.8,1.5,0.1))

# Chossing the optimum resolution parameter based on clustree output
library(clustree)

clustree(hazen.clusters1, prefix = "integrated_snn_res.")
clustree(hazen.clusters1, prefix = "integrated_snn_res." , node_colour = "sc3_stability")
clustree(hazen.clusters2, prefix = "integrated_snn_res.")
clustree(hazen.clusters2, prefix = "integrated_snn_res." , node_colour = "sc3_stability")

# Based on the results from clustree we choose r=0.4 to be the optimum 
han.com.clu <- FindClusters(hazen.combined, resolution = 0.4)

# Visualization
p1 <- DimPlot(han.com.clu, reduction = "umap", group.by = "stim")
p2 <- DimPlot(han.com.clu, reduction = "umap", label = TRUE)
p3 <- DimPlot(han.com.clu, reduction = "umap", split.by = "stim")

#plot_grid(p1, p2)
plot(p1)
plot(p2)
plot(p3)

# Checking for the expression of some marker genes
Genes <- read.csv(file="./Genes.csv" , header = FALSE)
Genes_vec <- as.vector(t(Genes))

DefaultAssay(han.com.clu) <- "RNA"

# Normalize RNA data for visualization purposes
han.com.clu <- NormalizeData(han.com.clu, verbose = FALSE)

ROS_Markers <- read.csv(file="./ROS Markers.csv" , header = FALSE)
ROS_Markers <- as.vector(t(ROS_Markers))
FeaturePlot(han.com.clu, features = ROS_Markers)

Hypoxia_markers <- read.csv(file="./Hypoxia markers.csv" , header = FALSE)
Hypoxia_markers <- as.vector(t(Hypoxia_markers))
FeaturePlot(han.com.clu, features = Hypoxia_markers)

Stemness_Markers <- read.csv(file="./Stemness Markers.csv" , header = FALSE)
Stemness_Markers <- as.vector(t(Stemness_Markers))
FeaturePlot(han.com.clu, features = Stemness_Markers)

Angiogenesis_Markers <- read.csv(file="./Angiogenesis Markers.csv" , header = FALSE)
Angiogenesis_Markers <- as.vector(t(Angiogenesis_Markers))
FeaturePlot(han.com.clu, features = Angiogenesis_Markers)

EMT_Markers <- read.csv(file="./EMT Markers.csv" , header = FALSE)
EMT_Markers <- as.vector(t(EMT_Markers))
FeaturePlot(han.com.clu, features = EMT_Markers)

Proliferation_Markers <- read.csv(file="./Proliferation Markers.csv" , header = FALSE)
Proliferation_Markers <- as.vector(t(Proliferation_Markers))
FeaturePlot(han.com.clu, features = Proliferation_Markers)

# Find markers between the two conditions
Idents(han.com.clu) <- han.com.clu@meta.data$stim
Cond_All_Markers <- FindMarkers(han.com.clu, ident.1 = "Gpx2KD", ident.2 = "NTtumor", min.pct = 0.25 , thresh.test = 0.25 , verbose = FALSE)
Cond_DE_genes <- rownames(Cond_All_Markers)
Cond_All_Markers[,6] <- Cond_DE_genes
colnames(Cond_All_Markers)[6] <- "gene"
genes_of_interest <- intersect(Genes_vec,Cond_DE_genes)

library(dplyr)
library(DataCombine)
InterestedMarkers <- grepl.sub(Cond_All_Markers,pattern = Genes_vec , Var = "gene")

write.csv(Cond_All_Markers , file = "./All_Markers_Cond.csv")
write.csv(InterestedMarkers , file = "./All_InterestedMarkers_Cond.csv")

# Plotting some genes of interest
FeaturePlot(han.com.clu, features = c("Romo1" , "Gpx4" , "Prdx5" , "Ndufb9"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("Mmp2" , "Vegfa" , "Hey1"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("Cd24a" , "Epcam"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("Hif1a" , "Mcl1" , "Slc2a1" , "Anxa1"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("Myc"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("Sox9" , "Sox4"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))

FeaturePlot(han.com.clu, features = "Ppargc1a", max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = "Gpx2", max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))

VlnPlot(han.com.clu, features = "Gpx2")
VlnPlot(han.com.clu, features = "Gpx2", split.by = "stim")
VlnPlot(han.com.clu, features = "Gpx2", slot = "SCT")

FeaturePlot(han.com.clu, features = c("Prkaa1" , "Acaca"), max.cutoff = 3 , split.by = "stim")


# Marker genes of differential expression between two conditions (GPx2sh vs. NT tumor) for each cluster from 0 to 6
han.com.clu$celltype.stim <- paste(Idents(han.com.clu), han.com.clu$stim, sep = "_")
han.com.clu$celltype <- Idents(han.com.clu)
Idents(han.com.clu) <- "celltype.stim"

Cond_Clst0_Markers <- FindMarkers(han.com.clu, ident.1 = "0_Gpx2KD", ident.2 = "0_NTtumor", min.pct = 0.25 , thresh.test = 0.25 ,verbose = FALSE)
Cond_Clst1_Markers <- FindMarkers(han.com.clu, ident.1 = "1_Gpx2KD", ident.2 = "1_NTtumor", min.pct = 0.25 , thresh.test = 0.25 ,verbose = FALSE)
Cond_Clst2_Markers <- FindMarkers(han.com.clu, ident.1 = "2_Gpx2KD", ident.2 = "2_NTtumor", min.pct = 0.25 , thresh.test = 0.25 ,verbose = FALSE)
Cond_Clst3_Markers <- FindMarkers(han.com.clu, ident.1 = "3_Gpx2KD", ident.2 = "3_NTtumor", min.pct = 0.25 , thresh.test = 0.25 ,verbose = FALSE)
Cond_Clst4_Markers <- FindMarkers(han.com.clu, ident.1 = "4_Gpx2KD", ident.2 = "4_NTtumor", min.pct = 0.25 , thresh.test = 0.25 ,verbose = FALSE)
Cond_Clst5_Markers <- FindMarkers(han.com.clu, ident.1 = "5_Gpx2KD", ident.2 = "5_NTtumor", min.pct = 0.25 , thresh.test = 0.25 ,verbose = FALSE)
Cond_Clst6_Markers <- FindMarkers(han.com.clu, ident.1 = "6_Gpx2KD", ident.2 = "6_NTtumor", min.pct = 0.25 , thresh.test = 0.25 ,verbose = FALSE)

write.csv(Cond_Clst0_Markers, file = "./Cond_Clst0_Markers.csv")
write.csv(Cond_Clst1_Markers, file = "./Cond_Clst1_Markers.csv")
write.csv(Cond_Clst2_Markers, file = "./Cond_Clst2_Markers.csv")
write.csv(Cond_Clst3_Markers, file = "./Cond_Clst3_Markers.csv")
write.csv(Cond_Clst4_Markers, file = "./Cond_Clst4_Markers.csv")
write.csv(Cond_Clst5_Markers, file = "./Cond_Clst5_Markers.csv")
write.csv(Cond_Clst6_Markers, file = "./Cond_Clst6_Markers.csv")

Cond_Clst7_Markers <- FindMarkers(han.com.clu, ident.1 = "7_Gpx2KD", ident.2 = "7_NTtumor", min.pct = 0.25 , thresh.test = 0.25, verbose = FALSE)
Cond_Clst8_Markers <- FindMarkers(han.com.clu, ident.1 = "8_Gpx2KD", ident.2 = "8_NTtumor", min.pct = 0.25 , thresh.test = 0.25, verbose = FALSE)

levels(han.com.clu)

##############################################################################################################
# Afetr annotation of clusters 
# Rename the clusters
new.cluster.ids <- c("Luminal-like", "Luminal-like", "Luminal-like", "Basal/stem-like", "Luminal-like", "Luminal-like",
                     "Luminal-like", "Macrophage", "Fibroblast")
names(new.cluster.ids) <- levels(han.com.clu)

han.com.clu <- RenameIdents(han.com.clu, '0' = '0 - Luminal-like', '1' = '1 - Luminal-like', '2' = '2 - Luminal-like', '3' = '3 - Basal/stem-like', '4' = '4 - Luminal-like', '5' = '5 - Luminal-like', '6' = '6 - Luminal-like', '7' = '7 - Macrophage', '8' = '8 - Fibroblast')

# to save Idents to metadata
# han.com.clu <- StashIdent(han.com.clu, save.name = 'idents')

han.com.clu <- ScaleData(han.com.clu, verbose = FALSE)

#Heatmap  of feature expression for the below marker genes across all the clusters
int_markers <-c("Krt8", "Krt18", "Epcam", "Cdh1", "Elf3", "Cd24a", "Cd49", "Mki67", "Cldn3", "Cldn7", "Actn4",
                "Vim", "Krt14", "Klf4", "Jag1", "Notch1", "Aldh2", "Itgb4", "Twist1", "Cd63", "Pfn1", "Ran", "Mylk", "Itga6", "Arc", "Sparc",
                "Adgre1", "Ccr5", "S100a4", "Col14a1", "Col1a2")
DoHeatmap(han.com.clu, features = int_markers)

int_markers_ord <- c("Col1a2", "Col14a1", "S100a4", "Arc", "Adgre1", "Krt14", "Sparc", "Ccr5", "Cldn3", "Vim", "Cldn7", "Krt18", "Aldh2", "Cd24a", "Elf3",
                     "Krt8", "Epcam", "Itgb4", "Mylk", "Klf4", "Jag1", "Pfn1", "Ran", "Cd63", "Twist1", "Actn4", "Cdh1", "Mki67", "Ccnb2", "Cdk1", "Ccnb1",
                     "Ccnd1", "Notch1", "Itga6")

# Dot plot to show the percentage of cells expressing oxidative features and the average expression level across all the clusters from 0 to 6.
markers.to.plot01 <- c("mt-Nd5", "mt-Atp6", "mt-Co3", "mt-Nd2", "mt-Nd1", "mt-Nd4", "mt-Co2", "mt-Cytb", "mt-Co1", "mt-Nd4l", "mt-Atp8")
DotPlot(han.com.clu, features = rev(markers.to.plot01), dot.scale = 8) + scale_colour_gradient2(high = "red")

markers.to.plot02 <- c("Romo1", "Hif1a", "Nfe2l1", "Sod1", "Mafg", "Prkca", "Prdx5", "Txnrd1", "Pclaf", "Pcna", "Fos", "Anxa1")
#DotPlot(han.com.clu, features = rev(markers.to.plot02), cols = "Reds", dot.scale = 8)
DotPlot(han.com.clu, features = rev(markers.to.plot02), dot.scale = 8) + scale_colour_gradient2(high = "red")

markers.to.plot03 <- c("Hif1a", "Nfe2l1", "Nfkb1", "Slc2a1", "Pgk1", "Vegfa", "Aldoc", "Ndrg1", "Aldoa", "Bnip3", "Ldha", "F3", "Tnf", "Ero1l")
DotPlot(han.com.clu, features = rev(markers.to.plot03), dot.scale = 8) + scale_colour_gradient2(high = "red")

# show that GPx2 knockdown increases the features of oxidative phosphorylation, hypoxia response and cancer stemness
# The marker genes for Mitochondria respiration-oxidative phosphorylation
FeaturePlot(han.com.clu, features = c("mt-Nd5" , "mt-Nd4l"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("Ndufa1" , "Cox6c"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("Atp5k" , "Ndufb2"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))

FeaturePlot(han.com.clu, features = c("Pgk1" , "Aldoa"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("Bnip3" , "Ldha"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("F3" , "Ero1l"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = "Higd1a", max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))

FeaturePlot(han.com.clu, features = c("Slc20a1", "Cxcl5"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("Mki67", "Ly6a"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))


FeaturePlot(han.com.clu, features = "Gsk3b", max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = "Itga6", max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = "Itgb4", max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))

# To statistically show that GPx2 knockdown really affect cells
# population changes under two conditions, we need to show the actual cells number of each cluster 0 to 6 over total cells number under two conditions
table(han.com.clu@meta.data$integrated_snn_res.0.4, han.com.clu@meta.data$orig.ident)


# Volcano plots for DE genes
library(EnhancedVolcano)

Clus_All_Markers <- read.csv("./Clus_All_Markers.csv", header = TRUE, row.names = 1)
EnhancedVolcano(Clus_All_Markers,
                lab = rownames(Clus_All_Markers),
                x = 'avg_logFC',
                y = 'p_val_adj',
                xlim = c(-5, 8))

#######################################################################################
# Volcano plots
library(dplyr)
library(ggplot2)
library(ggrepel)

# Cluster 0
results = read.csv("./Clus_0_cond.csv")

results$significance <- "Not significant"
results$significance[results$pvalue < 0.05] <- "p-value<0.05"
results$significance[results$log2FoldChange > 1] <- "Gpx2KD Upreg DEG"
results$significance[results$log2FoldChange < -1] <- "NTtumor Upreg DEG"
results$significance <- factor(results$significance, levels=c("NS", "p-value<0.05", "Gpx2KD Upreg DEG", "NTtumor Upreg DEG"))

p <- ggplot(data = results, aes(x=log2FoldChange, y=-log10(pvalue)) ) +
  geom_point(aes(color=significance)) +
  scale_color_manual(values=c("orange", "red", "green"))
p

p+geom_text(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

q <- p+geom_text_repel(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

r <- q + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
               panel.background = element_blank(), axis.line = element_line(colour = "black"))

r + theme(legend.key = element_rect(fill = "transparent", colour = "transparent")) + theme(legend.position = 'bottom') + theme(legend.title = element_blank())

# to put a title to ggplot and have it centered
# ggtitle("Gpx2KD Vs NTtumor") + theme(plot.title = element_text(hjust = 0.5))

# Cluster 01
results = read.csv("./Clus_1_cond.csv")

results$significance <- "Not significant"
results$significance[results$pvalue < 0.05] <- "p-value<0.05"
results$significance[results$log2FoldChange > 1] <- "Gpx2KD Upreg DEG"
results$significance[results$log2FoldChange < -1] <- "NTtumor Upreg DEG"
results$significance <- factor(results$significance, levels=c("Not significant", "p-value<0.05", "Gpx2KD Upreg DEG", "NTtumor Upreg DEG"))

p <- ggplot(data = results, aes(x=log2FoldChange, y=-log10(pvalue)) ) +
  geom_point(aes(color=significance)) +
  scale_color_manual(values=c("black", "orange", "red", "green"))
p

p+geom_text(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

q <- p+geom_text_repel(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

r <- q + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
               panel.background = element_blank(), axis.line = element_line(colour = "black"))

r + theme(legend.key = element_rect(fill = "transparent", colour = "transparent")) + theme(legend.position = 'bottom') + theme(legend.title = element_blank())

# Cluster 02
results <- read.csv("./Clus_2_cond.csv")

results$significance <- "Not significant"
results$significance[results$pvalue < 0.05] <- "p-value<0.05"
results$significance[results$log2FoldChange > 1] <- "Gpx2KD Upreg DEG"
results$significance[results$log2FoldChange < -1] <- "NTtumor Upreg DEG"
results$significance <- factor(results$significance, levels=c("NS", "p-value<0.05", "Gpx2KD Upreg DEG", "NTtumor Upreg DEG"))

p <- ggplot(data = results, aes(x=log2FoldChange, y=-log10(pvalue)) ) +
  geom_point(aes(color=significance)) +
  scale_color_manual(values=c("orange", "red", "green"))
p

p+geom_text(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

q <- p+geom_text_repel(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

r <- q + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
               panel.background = element_blank(), axis.line = element_line(colour = "black"))

r + theme(legend.key = element_rect(fill = "transparent", colour = "transparent")) + theme(legend.position = 'bottom') + theme(legend.title = element_blank())

# Cluster 03
results <- read.csv("./Clus_3_cond.csv")

results$significance <- "Not significant"
results$significance[results$pvalue < 0.05] <- "p-value<0.05"
results$significance[results$log2FoldChange > 1] <- "Gpx2KD Upreg DEG"
results$significance[results$log2FoldChange < -1] <- "NTtumor Upreg DEG"
results$significance <- factor(results$significance, levels=c("Not significant", "p-value<0.05", "Gpx2KD Upreg DEG", "NTtumor Upreg DEG"))

p <- ggplot(data = results, aes(x=log2FoldChange, y=-log10(pvalue)) ) +
  geom_point(aes(color=significance)) +
  scale_color_manual(values=c("black", "orange", "red", "green"))
p

p+geom_text(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

q <- p+geom_text_repel(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

r <- q + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
               panel.background = element_blank(), axis.line = element_line(colour = "black"))

r + theme(legend.key = element_rect(fill = "transparent", colour = "transparent")) + theme(legend.position = 'bottom') + theme(legend.title = element_blank())

# Cluster 04
results <- read.csv("./Clus_4_cond.csv")

results$significance <- "Not significant"
results$significance[results$pvalue < 0.05] <- "p-value<0.05"
results$significance[results$log2FoldChange > 1] <- "Gpx2KD Upreg DEG"
results$significance[results$log2FoldChange < -1] <- "NTtumor Upreg DEG"
results$significance <- factor(results$significance, levels=c("Not significant", "p-value<0.05", "Gpx2KD Upreg DEG", "NTtumor Upreg DEG"))

p <- ggplot(data = results, aes(x=log2FoldChange, y=-log10(pvalue)) ) +
  geom_point(aes(color=significance)) +
  scale_color_manual(values=c("black", "orange", "red", "green"))
p

p+geom_text(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

q <- p+geom_text_repel(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

r <- q + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
               panel.background = element_blank(), axis.line = element_line(colour = "black"))

r + theme(legend.key = element_rect(fill = "transparent", colour = "transparent")) + theme(legend.position = 'bottom') + theme(legend.title = element_blank())

# Cluster 05
results <- read.csv("./Clus_5_cond.csv")

results$significance <- "Not significant"
results$significance[results$pvalue < 0.05] <- "p-value<0.05"
results$significance[results$log2FoldChange > 1] <- "Gpx2KD Upreg DEG"
results$significance[results$log2FoldChange < -1] <- "NTtumor Upreg DEG"
results$significance <- factor(results$significance, levels=c("Not significant", "p-value<0.05", "Gpx2KD Upreg DEG", "NTtumor Upreg DEG"))

p <- ggplot(data = results, aes(x=log2FoldChange, y=-log10(pvalue)) ) +
  geom_point(aes(color=significance)) +
  scale_color_manual(values=c("black", "orange", "red", "green"))
p

p+geom_text(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

q <- p+geom_text_repel(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

r <- q + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
               panel.background = element_blank(), axis.line = element_line(colour = "black"))

r + theme(legend.key = element_rect(fill = "transparent", colour = "transparent")) + theme(legend.position = 'bottom') + theme(legend.title = element_blank())

# Cluster 06
results <- read.csv("./Clus_6_cond.csv")

results$significance <- "Not significant"
results$significance[results$pvalue < 0.05] <- "p-value<0.05"
results$significance[results$log2FoldChange > 1] <- "Gpx2KD Upreg DEG"
results$significance[results$log2FoldChange < -1] <- "NTtumor Upreg DEG"
results$significance <- factor(results$significance, levels=c("Not significant", "p-value<0.05", "Gpx2KD Upreg DEG", "NTtumor Upreg DEG"))

p <- ggplot(data = results, aes(x=log2FoldChange, y=-log10(pvalue)) ) +
  geom_point(aes(color=significance)) +
  scale_color_manual(values=c("black", "orange", "red", "green"))
p

p+geom_text(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

q <- p+geom_text_repel(data=filter(results, (padj<0.05 & abs(log2FoldChange)>1)), aes(label=Gene))

r <- q + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
               panel.background = element_blank(), axis.line = element_line(colour = "black"))

r + theme(legend.key = element_rect(fill = "transparent", colour = "transparent")) + theme(legend.position = 'bottom') + theme(legend.title = element_blank())


VlnPlot(han.com.clu, features = "Hif1a", split.by = "stim")
VlnPlot(han.com.clu, features = "Vegfa", split.by = "stim")
VlnPlot(han.com.clu, features = "Mmp2", split.by = "stim")
VlnPlot(han.com.clu, features = "Sox9", split.by = "stim")
VlnPlot(han.com.clu, features = "Sox4", split.by = "stim")
VlnPlot(han.com.clu, features = "Klf4", split.by = "stim")
VlnPlot(han.com.clu, features = "Slc20a1", split.by = "stim")
VlnPlot(han.com.clu, features = "Slc2a1", split.by = "stim")
VlnPlot(han.com.clu, features = "Mki67", split.by = "stim")
VlnPlot(han.com.clu, features = "Ly6a", split.by = "stim")

# New Feature plots requested
FeaturePlot(han.com.clu, features = c("Romo1" , "Prdx5"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("Hif1a" , "Higd1a"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("Vegfa" , "Mmp2"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
FeaturePlot(han.com.clu, features = c("Slc2a1" , "Krt14"), max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))


# Find markers in cluster 5 with respect to all other cells
cluster5_markers <- FindMarkers(han.com.clu, ident.1 = "5", ident.2 = NULL, min.pct = 0.25 , thresh.test = 0.25 ,verbose = FALSE)
write.csv(cluster5_markers, file = "./Cluster5/cluster5_markers.csv")

write.csv(Cond_Clst5_Markers, file = "./Cluster5/Cond_Clst5_Markers.csv")

Cond_Clst5_Markers
List <- read.csv("./Cluster5/List.csv")

i=1

for(i in 1:nrow(List)){
  
  features = List[i,]
  name = features
  
  jpeg(file=sprintf("Markers/Cluster5/Plots/_%s.jpeg", name), height = 2000, width = 2000)
  FeaturePlot(han.com.clu, features = List[i,], max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))
  dev.off()
  
  i=i+1
}

FeaturePlot(han.com.clu, features = List[1:4,], max.cutoff = 3 , split.by = "stim", cols = c("grey", "red"))