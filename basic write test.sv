`include "uvm_macros.svh"
import uvm_pkg::*;

// AXI Memory Interface
interface axi_if(input bit clk, input bit resetn);
  logic awvalid;
  logic awready;
  logic [3:0] awid;
  logic [7:0] awlen;
  logic [2:0] awsize;
  logic [31:0] awaddr;
  logic [1:0] awburst;

  logic wvalid;
  logic wready;
  logic [31:0] wdata;
  logic wlast;

  logic bready;
  logic bvalid;
  logic [3:0] bid;
  logic [1:0] bresp;

  logic arvalid;
  logic arready;
  logic [3:0] arid;
  logic [31:0] araddr;
  logic [7:0] arlen;
  logic [2:0] arsize;
  logic [1:0] arburst;

  logic rvalid;
  logic rready;
  logic [31:0] rdata;
  logic rlast;
  logic [3:0] rid;
  logic [1:0] rresp;
endinterface

// AXI Memory Transaction
class axi_mem_transaction extends uvm_sequence_item;
  `uvm_object_utils(axi_mem_transaction)

  rand logic [3:0] awid;
  rand logic [31:0] awaddr;
  rand logic [7:0] awlen;
  rand logic [2:0] awsize;
  rand logic [1:0] awburst;
  rand logic [31:0] wdata;

  function new(string name = "axi_mem_transaction");
    super.new(name);
  endfunction
endclass

// AXI Memory Sequencer
class axi_mem_sequencer extends uvm_sequencer #(axi_mem_transaction);
  `uvm_component_utils(axi_mem_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

// AXI Memory Driver
class axi_mem_driver extends uvm_driver #(axi_mem_transaction);
  `uvm_component_utils(axi_mem_driver)

  virtual axi_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif)) 
      `uvm_error("axi_mem_driver", "No virtual interface specified for driver");
  endfunction

  virtual task run_phase(uvm_phase phase);
    axi_mem_transaction trans;
    forever begin
      seq_item_port.get_next_item(trans);

      // Drive the transaction on the AXI interface
      vif.awvalid <= 1;
      vif.awaddr  <= trans.awaddr;
      vif.awid    <= trans.awid;
      vif.awlen   <= trans.awlen;
      vif.awsize  <= trans.awsize;
      vif.awburst <= trans.awburst;
      vif.wdata   <= trans.wdata;
      vif.wvalid  <= 1;
      vif.wlast   <= 1;

      // Wait for ready signal
      @(posedge vif.clk);
      while (!vif.awready || !vif.wready) begin
        @(posedge vif.clk);
      end

      // Complete the transaction
      vif.awvalid <= 0;
      vif.wvalid  <= 0;

      seq_item_port.item_done();
    end
  endtask
endclass

// AXI Memory Monitor
class axi_mem_monitor extends uvm_monitor;
  `uvm_component_utils(axi_mem_monitor)

  virtual axi_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_error("axi_mem_monitor", "No virtual interface specified for monitor");
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      // Monitor the AXI transactions (implement details based on what needs to be observed)
    end
  endtask
endclass

// AXI Memory Agent
class axi_mem_agent extends uvm_agent;
  `uvm_component_utils(axi_mem_agent)

  axi_mem_driver driver;
  axi_mem_sequencer sequencer;
  axi_mem_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    driver = axi_mem_driver::type_id::create("driver", this);
    sequencer = axi_mem_sequencer::type_id::create("sequencer", this);
    monitor = axi_mem_monitor::type_id::create("monitor", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

// AXI Memory Environment
class axi_mem_env extends uvm_env;
  `uvm_component_utils(axi_mem_env)

  axi_mem_agent agent;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = axi_mem_agent::type_id::create("agent", this);
  endfunction
endclass

// Base Test
class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  axi_mem_env env;

  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi_mem_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    // The base test does nothing in its run_phase
    phase.drop_objection(this);
  endtask
endclass

// AXI Write Sequence
class axi_write_sequence extends uvm_sequence #(axi_mem_transaction);
  `uvm_object_utils(axi_write_sequence)

  function new(string name = "axi_write_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_mem_transaction trans;
    trans = axi_mem_transaction::type_id::create("trans");

    // Setup the transaction
    trans.awid = 4'h1;            // Transaction ID
    trans.awaddr = 32'h0000_0005; // Starting address
    trans.awlen = 8'h00;          // Single transfer (AWLEN + 1)
    trans.awsize = 3'b010;        // 4-byte transaction size
    trans.awburst = 2'b01;        // Incremental burst
    trans.wdata = 32'hDEAD_BEEF;  // Example data

    start_item(trans);
    if (!trans.randomize()) begin
      `uvm_error("axi_write_sequence", "Randomization failed!")
    end
    finish_item(trans);
  endtask
endclass

// Write Test
class write_test extends base_test;
  `uvm_component_utils(write_test)

  function new(string name = "write_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    // Start the write sequence
    axi_write_sequence write_seq;
    write_seq = axi_write_sequence::type_id::create("write_seq");
    write_seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

// Testbench Top
module tb;
  bit clk;
  bit resetn;

  axi_if vif(clk, resetn);

  initial begin
    clk = 0;
    resetn = 1;
    forever #5 clk = ~clk;
  end

  initial begin
    uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.env.agent.*", "vif", vif);
    run_test("write_test");
  end

  initial begin
    resetn = 0;
    #100;
    resetn = 1;
  end
endmodule
