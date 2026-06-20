# KFS_1 — Grub, boot and screen

**Version:** 1

**Summary:** The real code !

## What is this project?

KFS_1 is the first project of the **Kernel From Scratch** series. You write a
minimal kernel from scratch — no existing software, API, or libraries — that
boots via GRUB on the i386 (x86) architecture and prints characters to the
screen. The end goal of this first step is a basic "Hello world" kernel that
displays `42`.

## Introduction

> Welcome to the first Kernel from Scratch project.
>
> Finally some real coding. In the Kernel from Scratch subjects you are going to
> write a kernel from scratch, without any existing software, API, or such.
>
> Those kernel programming skills are not quite spread in the IT world, so
> **take your time** to understand each and every different point. One does not
> simply consider himself a 'Kernel developer' from drivers or syscalls
> alone — it's a package of skills.

## Purpose

The Kernel From Scratch is divided into many projects, each dealing with a
specific aspect of kernel programming, and **all of them are linked together**.
When you build features, keep your kernel flexible so functions easily fit in —
half the time on these projects is spent linking different aspects together
(e.g. memory code must exist before process/execution code, yet processes use
memory). So: keep your code *clean* and your internal API simple.

This first subject is an introduction to kernel development. It is not much
code, but it sets the bootable base everything later builds on.

---

See [goals](goals.md) for the concrete objectives and [rules](rules.md) for the
hard constraints. The full file index is in [README](README.md).
