## Git Ignore Setup for Quartus/EDA Projects

To keep the repository clean and avoid committing temporary or tool-generated files, each user should create a `.gitignore` file in the **root directory** of the project with the following contents:

```gitignore
# Ignore common Quartus/EDA tool output directories
db/
greybox_tmp/
incremental_db/
output_files/
simulation/

# Ignore common temporary or auto-generated files
*.bak
*.ipregen.rpt
*.txt
qmegawiz_errors_log.txt