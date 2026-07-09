# Load libraries
library(readxl)
library(dplyr)
library(ggplot2)
library(stringr)

# ----------------------------
# 1. Image & scale settings
# ----------------------------
pixel_size <- 0.37744         # µm per pixel
image_width_px <- 4600
image_height_px <- 3450

image_width_um <- image_width_px * pixel_size    # ≈ 1736.22 µm
image_height_um <- image_height_px * pixel_size  # ≈ 1302.17 µm

# ----------------------------
# 2. Load and process data
# ----------------------------
file_path <- "C:/Users/Compo/Desktop/Foxp2 Ntsr1 Cck Analysis/Foxp2 Ntsr1 Cck Project/Dot Plots/Sal2Pbn3 S9L.xlsx"
data <- read_excel(file_path)

# Categorization function
get_category <- function(class_string) {
  if (is.na(class_string)) return("Ignore")
  class_string <- str_trim(class_string)
  
  has_foxp2 <- str_detect(class_string, regex("Foxp2", ignore_case = TRUE))
  has_ntsr1 <- str_detect(class_string, regex("Ntsr1", ignore_case = TRUE))
  has_cck   <- str_detect(class_string, regex("Cck", ignore_case = TRUE))
  
  if (sum(c(has_foxp2, has_cck, has_ntsr1)) == 0) return("Ignore")
  
  if (has_foxp2 && !has_cck && !has_ntsr1) return("Foxp2")
  if (!has_foxp2 && has_cck && !has_ntsr1) return("Cck")
  if (!has_foxp2 && !has_cck && has_ntsr1) return("Ntsr1")
  if (has_foxp2 && has_cck && !has_ntsr1) return("Foxp2+Cck")
  if (has_foxp2 && !has_cck && has_ntsr1) return("Foxp2+Ntsr1")
  if (!has_foxp2 && has_cck && has_ntsr1) return("Cck+Ntsr1")
  if (has_foxp2 && has_cck && has_ntsr1) return("Foxp2+Cck+Ntsr1")
  
  return("Ignore")
}

# Filter & format data
cells <- data %>%
  filter(`Object type` == "Cell") %>%
  mutate(Classification = str_trim(Classification)) %>%
  mutate(Category = sapply(Classification, get_category)) %>%
  filter(Category %in% c("Ntsr1", "Foxp2+Ntsr1", "Cck+Ntsr1", "Foxp2+Cck+Ntsr1")) %>%
  rename(X = `Centroid X Âµm`, Y = `Centroid Y Âµm`) %>%
  mutate(Y = image_height_um - Y)  # Flip Y-axis (0,0 becomes bottom-left)

# Category colors
cells$Category <- factor(cells$Category, levels = c(
  "Ntsr1",
  "Foxp2+Ntsr1",
  "Cck+Ntsr1",
  "Foxp2+Cck+Ntsr1"
))

colors <- c(
  "Ntsr1" = "red",
  "Foxp2+Ntsr1" = "#9467bd",
  "Cck+Ntsr1" = "darkorange",
  "Foxp2+Cck+Ntsr1" = "black"
)

# ----------------------------
# 3. Create spatial plot
# ----------------------------
p <- ggplot(cells, aes(x = X, y = Y, fill = Category)) +
  geom_point(shape = 21, color = "black", size = 18, alpha = 1, stroke = 0.8) +
  scale_fill_manual(values = colors) +
  scale_x_continuous(limits = c(0, image_width_um), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0, image_height_um), expand = c(0, 0)) +
  coord_fixed(ratio = 1, clip = "off") +
  theme_void() +
  theme(
    legend.position = "none",
    plot.margin = margin(0, 0, 0, 0),
    panel.spacing = unit(0, "cm")
  )

# ----------------------------
# 4. Save plot (scaled down)
# ----------------------------
scale_factor <- 0.5  # Reduce to 50% size

ggsave("ntsr1_spatial_plot_scaled.tiff",
       plot = p,
       width = (image_width_um / 25.4) * scale_factor,
       height = (image_height_um / 25.4) * scale_factor,
       units = "in",
       dpi = 300)

# ----------------------------
# 5. Show the plot in RStudio
# ----------------------------
print(p)
