#!/usr/bin/osascript -l JavaScript

ObjC.import("stdlib")
Application("com.runningwithcrayons.Alfred").search($.getenv("paperless_keyword").slice(0, -1));
Application("com.runningwithcrayons.Alfred").runTrigger("gridDocuments", {inWorkflow: $.getenv("alfred_workflow_bundleid")});