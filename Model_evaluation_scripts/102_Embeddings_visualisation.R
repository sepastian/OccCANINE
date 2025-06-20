# Embedding visualisation
# Created:    2024-01-17
# Authors:    Christian Vedel [christian-vs@sam.sdu.dk],
#
# Purpose:    Reads predicted labels and produces evaluation results
#
# Output:     paste0("Data/Summary_data/Model_performance", model_name, ".csv")

# ==== Libraries ====
library(tidyverse)  
library(Rtsne)      
library(plotly)     
source("Model_evaluation_scripts/000_Functions.R")

# ==== Load Data ==== 
key = read_csv("Data/Key.csv")

n_max = 10000
embeddings_w_lang = read_csv('Data/Predictions/PredictionsCANINE/embeddings_w_lang.csv', n_max = n_max)[,-1]
embeddings_w_lang_base = read_csv('Data/Predictions/PredictionsCANINE/embeddings_w_lang_base.csv', n_max = n_max)[,-1]
embeddings_wo_lang = read_csv('Data/Predictions/PredictionsCANINE/embeddings_wo_lang.csv', n_max = n_max)[,-1]
embeddings_wo_lang_base = read_csv('Data/Predictions/PredictionsCANINE/embeddings_wo_lang_base.csv', n_max = n_max)[,-1]
pred_data = read_csv('Data/Predictions/PredictionsCANINE/pred_data.csv', n_max = n_max)

# ===== Prepare Data ====
pred_data = pred_data %>% 
  mutate( # Only one hisco code
    only1 = is.na(hisco_2)*is.na(hisco_3)*is.na(hisco_4)*is.na(hisco_5)
  ) %>% 
  left_join(key, by = c(hisco_1="hisco"))

prep_emb = function(x){
  x$occ1 = pred_data$occ1
  x$hisco_1 = pred_data$hisco_1
  x$only1 = pred_data$only1
  x$lang = pred_data$lang
  x$en_hisco_text = pred_data$en_hisco_text
  x = x %>% 
    mutate(
      hisco_1 = Fix_HISCO(hisco_1)
    ) %>% 
    filter(only1==1) %>% 
    mutate(
      first_digit = substr(hisco_1, 1, 1)
    ) %>% 
    mutate(
      first_digit = ifelse(first_digit=="-", "-1", first_digit)
    )
  
  x = x %>% # Only unique values
    group_by(occ1, lang) %>% 
    summarise_all(~.x[1]) %>% 
    ungroup()
  
  return(x)
}


# ==== Function Definitions ====
construct_label = function(x){
  paste0(
    "Input: '", x$occ1, "'", " (lang: ", x$lang, ")\n",
    "HISCO: ", x$hisco_1,", Description: ", x$en_hisco_text
  )
}

# visualize_embeddings: Function to perform t-SNE and generate plots
run_tsne = function(embeddings) {
  # t-SNE Computation
  set.seed(20)  # for reproducibility
  tmp = embeddings %>% select(-c(occ1, hisco_1, only1, first_digit, lang, en_hisco_text)) 
  tsne_results = Rtsne(tmp, dims=2, perplexity=30, theta=0.0, check_duplicates=FALSE, max_iter = 10000)
  # tsne_results3d = Rtsne(tmp, dims=3, perplexity=30, theta=0.0, check_duplicates=FALSE, max_iter = 10000)
  
  # Merge t-SNE results with labels
  tsne_data = as.data.frame(tsne_results$Y)
  tsne_data$first_digit = embeddings$first_digit
  tsne_data$label = construct_label(embeddings)
  
  # tsne_data3d = as.data.frame(tsne_results3d$Y)
  # tsne_data3d$first_digit = embeddings$first_digit
  # tsne_data3d$label = construct_label(embeddings)
  
  return(
    tsne_data
  )
  
}

plot_emb = function(tsne_data, name){
  
  # 2D Visualization using ggplot2
  p1 = tsne_data %>% 
    ggplot(aes(x=V1, y=V2, col = first_digit)) +
    geom_point(alpha=0.7) +
    labs(
      paste(name, '2D t-SNE Visualization'),
      col = "First HISCO\ndigit"
    ) +
    theme_bw() + 
    theme(legend.position = "bottom") 
  
  print(p1)
  # Save 2D plot as PNG
  ggsave(paste0("Project_dissemination/Figures for paper/",name, "_tsne_2d.pdf"), plot=p1, width=4, height=5)
  ggsave(paste0("Project_dissemination/Figures for paper/",name, "_tsne_2d.png"), plot=p1, width=4, height=5, dpi = 600)
  
  # # Interactive Visualization using plotly
  # p2d = plot_ly(tsne_data, x = ~V1, y = ~V2, text = ~label, mode = 'markers', color = ~first_digit, marker = list(opacity=0.7)) %>%
  #   layout(title = paste0("Embedding space (t-sne)<br><sup>",name,"</sup>"))
  # fname = paste0("Eval_plots/Embedding_tsne/",name, "Interactive_tsne_2d.Rdata") 
  # save(p2d, file = fname)
  # 
  # 
  # # 3D Interactive Visualization using plotly
  # p3d = plot_ly(tsne_data3d, x = ~V1, y = ~V2, z = ~V3, text = ~label, mode = 'markers', color = ~first_digit, marker = list(opacity=0.7)) %>%
  #   layout(title = paste0("Embedding space (t-sne)<br><sup>",name,"</sup>"))
  # fname = paste0("Eval_plots/Embedding_tsne/",name, "Interactive_tsne_3d.Rdata") 
  # save(p3d, file = fname)
  
  
  return(
    tsne_data
  )
  
}

# ==== Main Execution ====
res_w_lang = embeddings_w_lang %>% 
  prep_emb() %>% 
  run_tsne() %>% 
  plot_emb("CANINE_finetuned_w._lang")

res_w_lang_base = embeddings_w_lang_base %>% 
  prep_emb() %>% 
  run_tsne() %>% 
  plot_emb("CANINE_baseline_w._lang")

# res_wo_lang = embeddings_wo_lang %>% 
#   prep_emb() %>% 
#   run_tsne() %>% 
#   plot_emb("CANINE_finetuned_wo._lang")
# 
# res_wo_lang_base = embeddings_wo_lang_base %>% 
#   prep_emb() %>% 
#   run_tsne() %>% 
#   plot_emb("CANINE_baseline_wo._lang")

# ==== Plot of both at once ====
res_w_lang = res_w_lang %>% 
  mutate(
    Model = "(b) OccCANINE"
  )

res_w_lang_base = res_w_lang_base %>% 
  mutate(
    Model = "(a) CANINE"
  )

p1 = res_w_lang_base %>% 
  bind_rows(res_w_lang) %>% 
  ggplot(aes(x=V1, y=V2, col = first_digit)) +
  geom_point(alpha=0.7, size = 0.5) +
  labs(
    col = "First HISCO\ndigit"
  ) +
  facet_wrap(~Model) +
  theme_bw() + 
  theme(
    legend.position = "bottom", 
    legend.title=element_text(size = 8)
  )
p1

ggsave(
  "Project_dissemination/Figures for paper/Plot_tsne_2d.pdf", 
  plot=p1, width=6, height=4, dpi = 600
)

ggsave(
  "Project_dissemination/Figures for paper/Plot_tsne_2d.png", 
  plot=p1, width=6, height=4, dpi = 600
)
  

