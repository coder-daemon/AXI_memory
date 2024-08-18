`include "uvm_macros.svh"
import uvm_pkg::*;

// AXI Memory Environment
class axi_mem_env extends uvm_env;
  `uvm_component_utils(axi_mem_env)

  axi_mem_agent agent;  // AXI memory agent

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = axi_mem_agent::type_id::create("agent", this);
  endfunction
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

// AXI Memory Driver
class axi_mem_driver extends uvm_driver #(axi_mem_transaction);
  `uvm_component_utils(axi_mem_driver)

  virtual axi_mem_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_mem_if)::get(this, "", "vif", vif)) 
      `uvm_error("axi_mem_driver", "No virtual interface specified for driver");
  endfunction

  virtual task run_phase(uvm_phase phase);
    axi_mem_transaction trans;
    forever begin
      seq_item_port.get_next_item(trans);
      // Drive the transaction on the AXI interface
      // (implementation based on your AXI design specifics)
      seq_item_port.item_done();
    end
  endtask
endclass

// AXI Memory Monitor
class axi_mem_monitor extends uvm_monitor;
  `uvm_component_utils(axi_mem_monitor)

  virtual axi_mem_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_mem_if)::get(this, "", "vif", vif))
      `uvm_error("axi_mem_monitor", "No virtual interface specified for monitor");
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      // Monitor the AXI transactions
      // (implementation depends on what needs to be observed)
    end
  endtask
endclass

// AXI Memory Sequencer
class axi_mem_sequencer extends uvm_sequencer #(axi_mem_transaction);
  `uvm_component_utils(axi_mem_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

// AXI Memory Transaction
class axi_mem_transaction extends uvm_sequence_item;
  `uvm_object_utils(axi_mem_transaction)

  // Define the transaction properties as per AXI protocol
  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit [3:0] id;
  rand bit [7:0] len;

  function new(string name = "axi_mem_transaction");
    super.new(name);
  endfunction
endclass

// AXI Memory Interface
interface axi_mem_if(input bit clk, input bit resetn);
  // Define the AXI signals here based on your design
endinterface

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
    // Start a sequence on the sequencer
    axi_mem_transaction trans;
    trans = axi_mem_transaction::type_id::create("trans");
    env.agent.sequencer.start(trans);
    phase.drop_objection(this);
  endtask
endclass

// Testbench Top
module tb;
  bit clk;
  bit resetn;

  axi_mem_if vif(clk, resetn);

  initial begin
    clk = 0;
    resetn = 1;
    forever #5 clk = ~clk;
  end

  initial begin
    uvm_config_db#(virtual axi_mem_if)::set(null, "uvm_test_top.env.agent.*", "vif", vif);
    run_test("base_test");
  end

  initial begin
    resetn = 0;
    #100;
    resetn = 1;
  end
endmodule
