################################################################################
# package_ip.tcl  —  AMD Vivado IP Packager script for axi2per
#
# Usage (Vivado Tcl console or batch mode):
#   vivado -mode batch -source scripts/package_ip.tcl
#   vivado -mode tcl  -source scripts/package_ip.tcl
#
# Output:
#   ip_output/axi2per/         — packaged IP directory (importable via IP Catalog)
#   ip_output/axi2per_1.0.zip  — portable IP archive
################################################################################

# ── Configuration ──────────────────────────────────────────────────────────────
set IP_NAME        "axi2per"
set IP_VERSION     "1.0"
set IP_VENDOR      "user.org"
set IP_LIBRARY     "user"
set IP_TAXONOMY    "/UserIP"
set IP_DISPLAY     "AXI to PULP Peripheral Bridge"
set IP_DESCRIPTION "Bridges AXI4 slave to PULP peripheral master. Supports configurable data widths (BEAT_RATIO bursts), one-hot ID encoding, and user field pass-through."

set REPO_ROOT      [file normalize [file dirname [file dirname [info script]]]]
set IP_OUT_DIR     "${REPO_ROOT}/ip_output/${IP_NAME}"
set IP_ARCHIVE     "${REPO_ROOT}/ip_output/${IP_NAME}_${IP_VERSION}.zip"
set PART           "xc7z020clg484-1"   ;# default part — change as needed

puts "=== axi2per IP Packager ==="
puts "  Repo root : ${REPO_ROOT}"
puts "  Output    : ${IP_OUT_DIR}"
puts "  Part      : ${PART}"
puts ""

# ── Collect RTL source files ────────────────────────────────────────────────────
# bender-generated filelist (regenerate if needed):
#   bender script verilator > scripts/verilator.f
# We read the list of project-owned .sv files from Bender.yml paths.
set RTL_FILES [list \
    "${REPO_ROOT}/src/axi2per_req_channel.sv" \
    "${REPO_ROOT}/src/axi2per_res_channel.sv" \
    "${REPO_ROOT}/src/axi2per.sv"             \
]

# Bender-fetched dependency files (axi_slice buffers).
# Run  `bender script vivado > /tmp/bender_vivado.tcl`  and source it, or
# list the files explicitly from .bender/git/checkouts/axi_slice-*/src/.
# Here we auto-discover them from the .bender cache:
set BENDER_SRC [glob -nocomplain \
    "${REPO_ROOT}/.bender/git/checkouts/axi_slice-*/src/*.sv"]
if {[llength $BENDER_SRC] == 0} {
    puts "WARNING: No .bender source files found."
    puts "         Run 'bender update' first, or add paths manually."
}
set ALL_FILES [concat $RTL_FILES $BENDER_SRC]

# ── Create/refresh IP output directory ─────────────────────────────────────────
file mkdir "${REPO_ROOT}/ip_output"
if {[file exists $IP_OUT_DIR]} {
    file delete -force $IP_OUT_DIR
}
file mkdir $IP_OUT_DIR

# ── Create Vivado managed-IP project ───────────────────────────────────────────
create_project -force ${IP_NAME}_prj "${REPO_ROOT}/ip_output/${IP_NAME}_prj" \
    -part $PART

set_property target_language SystemVerilog [current_project]

# Add all source files
add_files -norecurse $ALL_FILES
set_property file_type SystemVerilog [get_files *.sv]

# Set top module
set_property top axi2per [current_fileset]
update_compile_order -fileset sources_1

# ── Run IP Packager ─────────────────────────────────────────────────────────────
ipx::package_project \
    -root_dir    $IP_OUT_DIR       \
    -vendor      $IP_VENDOR        \
    -library     $IP_LIBRARY       \
    -taxonomy    $IP_TAXONOMY      \
    -import_files                  \
    -set_current_ip

set core [ipx::current_core]

# ── IP Metadata ─────────────────────────────────────────────────────────────────
set_property vendor              $IP_VENDOR      $core
set_property library             $IP_LIBRARY     $core
set_property name                $IP_NAME        $core
set_property version             $IP_VERSION     $core
set_property display_name        $IP_DISPLAY     $core
set_property description         $IP_DESCRIPTION $core
set_property vendor_display_name "User"          $core
set_property company_url         ""              $core
set_property supported_families  \
    "zynq Production zynquplus Production versal Production" $core

# ── Auto-infer standard interfaces ─────────────────────────────────────────────
# Vivado recognises aclk/aresetn/s_axi_* naming automatically.
ipx::infer_bus_interfaces xilinx.com:interface:aximm_rtl:1.0 $core
ipx::infer_bus_interfaces xilinx.com:signal:clock_rtl:1.0    $core
ipx::infer_bus_interfaces xilinx.com:signal:reset_rtl:1.0    $core

# ── Configure S_AXI interface parameters ───────────────────────────────────────
set s_axi_if [ipx::get_bus_interfaces S_AXI -of_objects $core]
if {$s_axi_if ne ""} {
    # Map AXI interface parameters to module parameters
    set_property value_resolve_type user \
        [ipx::get_bus_parameters -of_objects $s_axi_if DATA_WIDTH]
    set_property value "AXI_DATA_WIDTH" \
        [ipx::get_bus_parameters -of_objects $s_axi_if DATA_WIDTH]

    set_property value_resolve_type user \
        [ipx::get_bus_parameters -of_objects $s_axi_if ADDR_WIDTH]
    set_property value "AXI_ADDR_WIDTH" \
        [ipx::get_bus_parameters -of_objects $s_axi_if ADDR_WIDTH]

    set_property value_resolve_type user \
        [ipx::get_bus_parameters -of_objects $s_axi_if ID_WIDTH]
    set_property value "AXI_ID_WIDTH" \
        [ipx::get_bus_parameters -of_objects $s_axi_if ID_WIDTH]
} else {
    puts "WARNING: S_AXI interface not found — check port names in axi2per.sv"
}

# ── Clock frequency parameter ───────────────────────────────────────────────────
set clk_if [ipx::get_bus_interfaces ACLK -of_objects $core]
if {$clk_if ne ""} {
    ipx::add_bus_parameter FREQ_HZ $clk_if
    set_property value 100000000 \
        [ipx::get_bus_parameters FREQ_HZ -of_objects $clk_if]
}

# ── GUI Parameter configuration ─────────────────────────────────────────────────
# Mark parameters that should appear in the IP Customization GUI.
foreach param_name {
    PER_ADDR_WIDTH PER_DATA_WIDTH
    AXI_ADDR_WIDTH AXI_DATA_WIDTH AXI_USER_WIDTH AXI_ID_WIDTH
    PER_ID_WIDTH BUFFER_DEPTH
} {
    set p [ipx::get_user_parameters ${param_name} -of_objects $core]
    if {$p ne ""} {
        set_property value_resolve_type user $p
    }
}

# PER_ID_WIDTH: derived from AXI_ID_WIDTH (read-only in GUI)
set pid [ipx::get_user_parameters PER_ID_WIDTH -of_objects $core]
if {$pid ne ""} {
    set_property value_resolve_type immediate $pid
    set_property enablement_value false $pid
}

# Add display names / descriptions for key parameters
proc set_param_display {core name display_name desc} {
    set p [ipx::get_user_parameters ${name} -of_objects $core]
    if {$p ne ""} {
        set_property display_name $display_name $p
        set_property description  $desc         $p
    }
}
set_param_display $core PER_DATA_WIDTH "Peripheral Data Width" \
    "Data bus width of the PULP peripheral port (bits). Must be a power-of-2 multiple of AXI_DATA_WIDTH."
set_param_display $core AXI_DATA_WIDTH "AXI Data Width" \
    "AXI4 data bus width (bits). Typical values: 32, 64, 128, 256."
set_param_display $core AXI_ID_WIDTH   "AXI ID Width" \
    "AXI4 transaction ID width (bits, binary encoding)."
set_param_display $core PER_ID_WIDTH   "Peripheral ID Width" \
    "One-hot peripheral ID width = 2^AXI_ID_WIDTH (auto-computed, read-only)."
set_param_display $core BUFFER_DEPTH   "AXI Channel Buffer Depth" \
    "FIFO depth for AW/AR/W/R/B channel buffers."

# ── Integrity check & save ──────────────────────────────────────────────────────
puts ""
puts "--- Checking IP integrity ---"
set check_result [ipx::check_integrity -quiet $core]
if {$check_result != 0} {
    puts "WARNING: IP integrity check reported issues (code=${check_result})."
    puts "         Review messages above before using the IP."
} else {
    puts "    IP integrity: OK"
}

ipx::save_core $core
puts "    Saved: ${IP_OUT_DIR}/component.xml"

# ── Archive ─────────────────────────────────────────────────────────────────────
puts ""
puts "--- Creating IP archive ---"
ipx::archive_core $IP_ARCHIVE $core
puts "    Archive: ${IP_ARCHIVE}"

# ── Register in current project's IP repository ─────────────────────────────────
set_property ip_repo_paths $IP_OUT_DIR [current_project]
update_ip_catalog

puts ""
puts "=== Packaging complete ==="
puts "  IP directory : ${IP_OUT_DIR}"
puts "  IP archive   : ${IP_ARCHIVE}"
puts ""
puts "To use in Vivado:"
puts "  1. IP Catalog → Add Repository → select ${IP_OUT_DIR}"
puts "  2. Search for 'axi2per' and instantiate"
puts "  OR"
puts "  1. IP Catalog → Add Repository → select the .zip archive"
